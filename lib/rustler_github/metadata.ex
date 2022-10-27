defmodule RustlerGithub.Metadata do
  alias RustlerGithub.{Config, Util}

  defstruct [
    :cached_file,
    :lib_name,
    :file_name,
    :target
  ]

  def build(%Config{} = config) do
    target = RustlerGithub.Arch.target()
    lib_name = format(config.format, target, config.crate, config.version)

    file_name = lib_name_with_ext(target, lib_name)

    cached_file = Path.join(cache_dir("precompiled"), "#{file_name}.#{config.ext}")

    %__MODULE__{
      cached_file: cached_file,
      lib_name: lib_name,
      file_name: file_name,
      target: target
    }
  end

  def read(nif_module) when is_atom(nif_module) do
    nif_module
    |> path()
    |> Util.eval_map()
  end

  def write!(nif_module, %__MODULE__{} = metadata) do
    existing = read(nif_module)

    unless Map.equal?(metadata, existing) do
      file = path(nif_module)
      dir = Path.dirname(file)
      :ok = File.mkdir_p(dir)

      File.write!(file, inspect(metadata, limit: :infinity, pretty: true))
    end

    :ok
  end

  defp format(fmt, target, name, version) do
    fmt
    |> String.replace("{name}", lib_prefix(target) <> name)
    |> String.replace("{version}", version)
    |> String.replace("{target}", target)
  end

  defp lib_prefix(target) do
    if String.contains?(target, "windows") do
      ""
    else
      "lib"
    end
  end

  defp lib_name_with_ext(target, lib_name) do
    ext =
      if String.contains?(target, "windows") do
        "dll"
      else
        "so"
      end

    "#{lib_name}.#{ext}"
  end

  defp cache_dir(sub_dir) do
    cache_opts = if System.get_env("MIX_XDG"), do: %{os: :linux}, else: %{}
    :filename.basedir(:user_cache, Path.join("rustler_github", sub_dir), cache_opts)
  end

  defp path(nif_module) when is_atom(nif_module) do
    dir = cache_dir("metadata")
    Path.join(dir, "metadata-#{nif_module}.exs")
  end
end
