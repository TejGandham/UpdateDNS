defmodule PublicIPFetcher do
  def get_public_ip do
    case HTTPoison.get("https://ifconfig.co/json") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Poison.decode(body) do
          {:ok, %{"ip" => ip}} -> {:ok, ip}
          {:error, reason} -> {:error, "Failed to parse public IP response: #{inspect(reason)}"}
        end

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Failed to get public IP: HTTP status code #{status_code}"}

      {:error, reason} ->
        {:error, "Failed to get public IP: #{inspect(reason)}"}
    end
  end
end
