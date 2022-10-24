defmodule RustlerGithub.Config do
  @moduledoc false

  # This is an internal struct to represent valid config options.
  defstruct [
    :otp_app,
    :module,
    :org,
    :repo,
    :version,
    :crate,
    :load_from,
    :base_cache_dir,
    :force_build?,
    :format,
    :token
  ]

  def new(opts) do
    %__MODULE__{
      otp_app: Keyword.fetch!(opts, :otp_app),
      org: Keyword.fetch!(opts, :org),
      repo: Keyword.fetch!(opts, :repo),
      module: Keyword.fetch!(opts, :module),
      version: Keyword.fetch!(opts, :version),
      force_build?: Keyword.fetch!(opts, :force_build),
      crate: opts[:crate],
      load_from: opts[:load_from],
      base_cache_dir: opts[:base_cache_dir],
      format: opts[:format],
      token: opts[:token]
    }
  end
end
