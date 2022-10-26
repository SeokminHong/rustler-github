defmodule RustlerGithub do
  require Logger
  alias RustlerGithub.{Config, Checksum, Metadata}

  @native_dir "priv/native"

  defmacro __using__(opts) do
    force =
      if Code.ensure_loaded?(Rustler) do
        quote do
          use Rustler, only_rustler_opts
        end
      else
        quote do
          raise "Rustler dependency is needed to force the build. " <>
                  "Add it to your `mix.exs` file: `{:rustler, \">= 0.0.0\", optional: true}`"
        end
      end

    quote do
      require Logger

      opts = unquote(opts)

      otp_app = Keyword.fetch!(opts, :otp_app)

      opts =
        Keyword.put_new(
          opts,
          :force_build,
          Application.compile_env(:rustler_precompiled, [:force_build, otp_app])
        )

      case RustlerPrecompiled.init(__MODULE__, opts) do
        {:force_build, only_rustler_opts} ->
          unquote(force)

        {:ok, config} ->
          @on_load :load_rustler_precompiled
          @rustler_precompiled_load_from config.load_from

          @doc false
          def load_rustler_precompiled do
            # Remove any old modules that may be loaded so we don't get
            # {:error, {:upgrade, 'Upgrade not supported by this NIF library.'}}
            :code.purge(__MODULE__)
            {otp_app, path} = @rustler_precompiled_load_from

            load_path =
              otp_app
              |> Application.app_dir(path)
              |> to_charlist()

            :erlang.load_nif(load_path, 0)
          end

        {:error, precomp_error} ->
          raise precomp_error
      end
    end
  end

  def init(module, opts) do
    config = Config.new(opts)
    metadata = Metadata.build(config)

    if config.force_build? do
      rustler_opts = Keyword.drop(opts, [:owner, :repo, :version, :force_build?, :format, :token])

      {:force_build, rustler_opts}
    else
      with {:error, precomp_error} <-
             download_or_reuse_nif_file(module, config, metadata) do
        message = """
        Error while downloading precompiled NIF: #{precomp_error}.
        """

        {:error, message}
      end
    end
  end

  @doc false
  def download_or_reuse_nif_file(nif_module, %Config{} = config, %Metadata{} = metadata)
      when is_map(metadata) do
    name = config.otp_app

    native_dir = Application.app_dir(name, @native_dir)

    lib_name = metadata.lib_name
    cached_file = metadata.cached_file
    cache_dir = Path.dirname(cached_file)

    file_name = metadata.file_name
    lib_file = Path.join(native_dir, file_name)

    result = %{
      load?: true,
      load_from: {name, Path.join("priv/native", lib_name)}
    }

    if File.exists?(cached_file) do
      # Remove existing NIF file so we don't have processes using it.
      # See: https://github.com/rusterlium/rustler/blob/46494d261cbedd3c798f584459e42ab7ee6ea1f4/rustler_mix/lib/rustler/compiler.ex#L134
      File.rm(lib_file)

      with :ok <- Checksum.check(cached_file, nif_module),
           :ok <- :erl_tar.extract(cached_file, [:compressed, cwd: Path.dirname(lib_file)]) do
        Logger.debug("Copying NIF from cache and extracting to #{lib_file}")
        {:ok, result}
      end
    else
      dirname = Path.dirname(lib_file)

      with :ok <- File.mkdir_p(cache_dir),
           :ok <- File.mkdir_p(dirname),
           {:ok, tar_gz} <- download_release(config, metadata),
           :ok <- File.write(cached_file, tar_gz),
           :ok <- Checksum.check(cached_file, nif_module),
           :ok <-
             :erl_tar.extract({:binary, tar_gz}, [:compressed, cwd: Path.dirname(lib_file)]) do
        Logger.debug("NIF cached at #{cached_file} and extracted to #{lib_file}")

        {:ok, result}
      end
    end
  end

  defp download_release(%Config{} = config, %Metadata{} = metadata) do
    with {:ok,
          %Neuron.Response{
            body: %{
              "data" => %{
                "repository" => %{
                  "release" => %{
                    "releaseAssets" => %{
                      "nodes" => assets
                    }
                  }
                }
              }
            }
          }} <- get_assets(config),
         %{"downloadUrl" => download_url} <-
           Enum.find(assets, fn %{"name" => name} ->
             name == metadata.file_name
           end),
         {:ok,
          %HTTPoison.Response{
            body: body
          }} = HTTPoison.get(download_url) do
      {:ok, body}
    end
  end

  defp get_assets(%Config{} = config) do
    Neuron.query(
      """
      query getUrl($owner: String!, $name: String!, $version: String!) {
        repository(owner: $owner, name: $name) {
          release(tagName: $version) {
            releaseAssets(first: 100) {
              nodes {
                name
                downloadUrl
              }
            }
          }
        }
      }
      """,
      %{owner: config.owner, name: config.repo, version: config.version},
      url: "https://api.github.com/graphql",
      headers: [{"Authorization", "Bearer #{config.token}"}, {"User-Agent", "Neuron"}]
    )
  end
end
