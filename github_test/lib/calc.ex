defmodule Calc do
  use RustlerGithub,
    otp_app: :github_test,
    crate: "calc",
    owner: "corp-momenti",
    repo: "rustler-github",
    tag: "calc",
    format: "{name}-{target}",
    ext: "tgz",
    token: System.get_env("TOKEN"),
    force_build?: System.get_env("RUSTLER_PRECOMPILED") in ["1", "true"]

  @spec add(integer(), integer()) :: integer()
  def add(_a, _b), do: error()

  defp error(), do: :erlang.nif_error(:nif_not_loaded)
end
