defmodule RustlerGithub.Util do
  def eval_map(file) do
    {%{} = content, _} = Code.eval_file(file)
    content
  rescue
    _ -> %{}
  end
end
