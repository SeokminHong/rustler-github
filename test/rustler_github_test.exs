defmodule RustlerGithubTest do
  use ExUnit.Case
  doctest RustlerGithub

  test "greets the world" do
    assert RustlerGithub.hello() == :world
  end
end
