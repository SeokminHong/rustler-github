defmodule RustlerGithub.Config do
  @moduledoc false

  # This is an internal struct to represent valid config options.
  defstruct [
    :otp_app,
    :owner,
    :repo,
    :tag,
    :crate,
    :load_from,
    :force_build?,
    :format,
    :token,
    :ext
  ]

  def new(opts) do
    %__MODULE__{
      otp_app: Keyword.fetch!(opts, :otp_app),
      owner: Keyword.fetch!(opts, :owner),
      repo: Keyword.fetch!(opts, :repo),
      tag: Keyword.fetch!(opts, :tag),
      crate: Keyword.fetch!(opts, :crate),
      load_from: opts[:load_from],
      force_build?: Keyword.fetch!(opts, :force_build),
      format: Keyword.get(opts, :format, "{name}-v{tag}-{target}"),
      token: opts[:token],
      ext: Keyword.get(opts, :ext, "tgz")
    }
  end
end
