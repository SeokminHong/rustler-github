defmodule RustlerGithub.Http do
  require Logger

  def query(url, q, token) do
    http_options = get_http_options()

    {:ok, {{_, 200, _}, _headers, body}} =
      :httpc.request(
        :post,
        {url,
         [
           {'Authorization', 'Bearer #{token}'},
           {'User-Agent', 'Elixir'}
         ], 'application/json', Jason.encode!(%{query: q})},
        http_options,
        []
      )

    Jason.decode(body)
  end

  def get_file(url) do
    http_options = get_http_options()

    with {:ok, {{_, 200, _}, _headers, body}} <-
           :httpc.request(
             :get,
             {url, []},
             http_options,
             body_format: :binary
           ),
         do: {:ok, body}
  end

  defp get_http_options() do
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)

    if proxy = System.get_env("HTTP_PROXY") || System.get_env("http_proxy") do
      Logger.debug("Using HTTP_PROXY: #{proxy}")
      %{host: host, port: port} = URI.parse(proxy)

      :httpc.set_options([{:proxy, {{String.to_charlist(host), port}, []}}])
    end

    proxy = System.get_env("HTTPS_PROXY") || System.get_env("https_proxy")

    with true <- is_binary(proxy),
         %{host: host, port: port} when is_binary(host) and is_integer(port) <- URI.parse(proxy) do
      Logger.debug("Using HTTPS_PROXY: #{proxy}")
      :httpc.set_options([{:https_proxy, {{String.to_charlist(host), port}, []}}])
    end

    # https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/inets
    cacertfile = CAStore.file_path() |> String.to_charlist()

    [
      ssl: [
        verify: :verify_peer,
        cacertfile: cacertfile,
        depth: 2,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
    ]
  end
end
