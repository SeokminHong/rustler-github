defmodule GithubTestTest do
  use ExUnit.Case
  doctest GithubTest

  test "add" do
    assert Calc.add(1, 2) == 3
  end
end
