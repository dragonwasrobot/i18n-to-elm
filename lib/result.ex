defmodule I18n2Elm.Result do
  @moduledoc """
  Helpers for composing functions that return `{:ok, _} | {:error, _}`.
  """

  @doc """
  Applies `fun` across `items`, collecting every `:ok` value in order. Stops
  at the first `:error` instead of continuing to process the rest of the
  list, since a single failure invalidates the whole batch.
  """
  @spec traverse([term()], (term() -> {:ok, term()} | {:error, term()})) ::
          {:ok, [term()]} | {:error, term()}
  def traverse(items, fun) do
    items
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
      case fun.(item) do
        {:ok, value} -> {:cont, {:ok, [value | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end
end
