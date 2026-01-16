defmodule UpdateCloudflareDNS.MixProject do
  use Mix.Project

  def project do
    [
      app: :update_dns,
      version: "0.2.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:logger_file_backend, "~> 0.0.14"}
    ]
  end
end
