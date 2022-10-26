defmodule RustlerGithub.Arch do
  defp system_arch() do
    base =
      :erlang.system_info(:system_architecture)
      |> List.to_string()
      |> String.split("-")

    triple_keys =
      case length(base) do
        4 ->
          [:arch, :vendor, :os, :abi]

        3 ->
          [:arch, :vendor, :os]

        _ ->
          # It's too complicated to find out, and we won't support this for now.
          []
      end

    triple_keys
    |> Enum.zip(base)
    |> Enum.into(%{})
  end

  defp system_arch_to_string(arch) do
    values =
      for key <- [:arch, :vendor, :os, :abi],
          value = arch[key],
          do: value

    Enum.join(values, "-")
  end

  defp normalize_arch_os(target_system) do
    cond do
      target_system.os =~ "darwin" ->
        arch = with "arm" <- target_system.arch, do: "aarch64"

        %{target_system | arch: arch, os: "darwin"}

      target_system.os =~ "linux" ->
        arch = with "amd64" <- target_system.arch, do: "x86_64"
        vendor = with vendor when vendor in ~w(pc redhat) <- target_system.vendor, do: "unknown"

        %{target_system | arch: arch, vendor: vendor}

      true ->
        target_system
    end
  end

  def target() do
    case :os.type() do
      {:unix, _} ->
        system_arch()
        |> normalize_arch_os()

      {:win32, _} ->
        # 32 or 64 bits
        arch =
          case :erlang.system_info(:wordsize) do
            4 -> "i686"
            8 -> "x86_64"
          end

        system_arch()
        |> Map.put_new(:arch, arch)
        |> Map.put_new(:vendor, "pc")
        |> Map.put_new(:os, "windows")
        |> Map.put_new(:abi, "msvc")
    end
    |> system_arch_to_string()
  end
end
