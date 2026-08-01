defmodule I18n2Elm.Infra.CLI do
  @moduledoc """
  Command-line argument parsing boundary: translates raw argv into
  positional paths and options, or the reason parsing didn't yield a
  runnable command.
  """

  @type unknown_argument :: %{flag: String.t(), value: String.t() | nil}
  @type reason :: :no_paths_given | {:unknown_arguments, [unknown_argument()]}

  @spec parse_args([String.t()]) :: {:ok, [Path.t()], keyword()} | {:error, reason()}
  def parse_args(args) do
    case OptionParser.parse(args, strict: [module_name: :string]) do
      {_options, [], _errors} ->
        {:error, :no_paths_given}

      {_options, _paths, [_ | _] = errors} ->
        {:error, {:unknown_arguments, unknown_arguments(errors)}}

      {options, paths, []} ->
        {:ok, paths, options}
    end
  end

  @spec unknown_arguments(OptionParser.errors()) :: [unknown_argument()]
  defp unknown_arguments(errors) do
    Enum.map(errors, fn {flag, value} -> %{flag: flag, value: value} end)
  end
end
