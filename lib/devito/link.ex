defmodule Devito.Link do
  @moduledoc """
  Schema for a link.
  """

  @enforce_keys [:url, :short_code]
  defstruct [:url, :short_code, :count, :created_at]

  @doc """
  Checks that a link is valid.
  `Valid` means the url is present and the short_code
  is both present and unique.
  """
  @spec valid?(%__MODULE__{}) :: boolean()
  def valid?(%__MODULE__{url: url, short_code: short_code}) do
    valid_uri?(url) and
      valid_short_code?(short_code)
  end

  def generate_short_code(retries \\ 5)
  def generate_short_code(0), do: nil

  def generate_short_code(retries) do
    short_code = do_generate_random_code()
    if valid_short_code?(short_code), do: short_code, else: generate_short_code(retries - 1)
  end

  @spec insert_link(%__MODULE__{}) :: :error | :ok
  def insert_link(link) do
    db = Devito.CubDB.db()

    if valid?(link) do
      CubDB.put(db, link.short_code, link)
    else
      :error
    end
  end

  def find_link(short_code) do
    db = Devito.CubDB.db()
    CubDB.get(db, short_code)
  end

  def increment_count(short_code) do
    db = Devito.CubDB.db()

    CubDB.get_and_update(db, short_code, fn
      nil ->
        {:error, :not_found}

      link ->
        link = %{link | count: link.count + 1}
        {:ok, link}
    end)
  end

  def all() do
    db = Devito.CubDB.db()
    CubDB.select(db)
  end

  defp valid_uri?(string) do
    parsed = URI.parse(string)

    parsed.host not in [nil, ""] and
      parsed.scheme not in [nil, ""] and
      String.starts_with?(parsed.scheme, "http")
  end

  defp valid_short_code?(string) do
    db = Devito.CubDB.db()

    resp =
      string not in [nil, ""] and
        is_nil(CubDB.get(db, string))

    resp
  end

  defp do_generate_random_code do
    short_code_chars = Application.get_env(:devito, :short_code_chars)

    Enum.reduce(0..5, [], fn _n, acc -> acc ++ Enum.take_random(short_code_chars, 1) end)
    |> List.to_string()
  end
end
