defmodule RustlerGithub.Checksum do
  alias RustlerGithub.{Metadata, Util}

  def check(file_path, nif_module) when is_atom(nif_module) do
    checksums = read(nif_module)
    basename = Path.basename(file_path)
    compare_checksum(file_path, checksums[basename])
  end

  def read(nif_module) when is_atom(nif_module) do
    nif_module
    |> path()
    |> Util.eval_map()
  end

  def write!(nif_module, checksums) when is_atom(nif_module) do
    metadata = Metadata.read(nif_module)

    case metadata do
      %{otp_app: _name} ->
        file = path(nif_module)

        pairs =
          for %{path: path, checksum: checksum} <- checksums, into: %{} do
            basename = Path.basename(path)
            {basename, checksum}
          end

        lines =
          for {filename, checksum} <- Enum.sort(pairs) do
            ~s(  "#{filename}" => #{checksum},\n)
          end

        File.write!(file, ["%{\n", lines, "}\n"])

      _ ->
        raise "could not find the OTP app for #{inspect(nif_module)} in the metadata file. " <>
                "Please compile the project again with: `mix compile --force`."
    end
  end

  @checksum_algo :sha256
  defp compare_checksum(file_path, expected_checksum) do
    case File.read(file_path) do
      {:ok, content} ->
        file_hash =
          :crypto.hash(@checksum_algo, content)
          |> Base.encode16(case: :lower)

        if file_hash == expected_checksum do
          :ok
        else
          {:error, "the integrity check failed because the checksum of files does not match"}
        end

      {:error, reason} ->
        {:error,
         "cannot read the file for checksum comparison: #{inspect(file_path)}. " <>
           "Reason: #{inspect(reason)}"}
    end
  end

  defp path(nif_module) when is_atom(nif_module) do
    Path.join(File.cwd!(), "checksum-#{nif_module}.exs")
  end
end
