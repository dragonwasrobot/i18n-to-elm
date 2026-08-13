defmodule I18n2Elm do
  @moduledoc ~S"""
  Transforms a folder of i18n key/value JSON files into a series of Elm types
  and functions.

  Expects a PATH to one or more JSON files from which to generate Elm code.

      i18n2elm PATH [--module-name PATH] [--output-mode native|web-component]

  The JSON files at the given PATH will be converted to Elm types and functions.

  ## Options

      * `--module-name` - the module name prefix for the printed Elm modules
      default value is 'Translations'.
      * `--output-mode` - either `native` (default), which generates one Elm
      module per language, or `web-component`, which generates a single
      dispatch module along with a `<i18n-text>` custom element and its
      runtime JSON assets.
  """

  require Logger
  alias I18n2Elm.Domain.{Parser, Printer}
  alias I18n2Elm.Infra.{CLI, FileSystem}
  alias I18n2Elm.Result
  alias Parser.I18nResource

  @type reason ::
          FileSystem.reason()
          | Parser.reason()
          | :missing_reference_translation

  @type output_mode :: :native | :web_component

  @spec main([String.t()]) :: no_return
  def main(args) do
    Logger.debug("Arguments: #{inspect(args)}")

    with {:ok, paths, options} <- CLI.parse_args(args),
         {:ok, files} <- FileSystem.resolve_all_paths(paths),
         {:ok, output_mode} <- resolve_output_mode(options),
         {:ok, module_name} <- FileSystem.create_output_dir(options),
         {:ok, written_files} <- generate(files, module_name, output_mode) do
      Logger.debug("Written files: #{inspect(written_files)}")
      exit(:normal)
    else
      {:error, :no_paths_given} ->
        IO.puts(@moduledoc)
        exit(:normal)

      {:error, {:unknown_arguments, errors}} ->
        IO.puts(:stderr, "Found one or more errors in the supplied options: #{inspect(errors)}")
        exit({:unknown_arguments, errors})

      {:error, {:invalid_output_mode, value}} ->
        IO.puts(:stderr, "Invalid --output-mode value: #{inspect(value)}")
        exit({:invalid_output_mode, value})

      {:error, {:no_files, paths}} ->
        IO.puts(:stderr, "Could not find any JSON files in path: #{inspect(paths)}")
        exit(:no_files)

      {:error, reason} ->
        IO.puts(:stderr, inspect(reason))
        exit(reason)
    end
  end

  @doc """
  Resolves the `--output-mode` flag in `options` into an `output_mode`,
  defaulting to `:native` when absent.
  """
  @spec resolve_output_mode(Keyword.t()) ::
          {:ok, output_mode()} | {:error, {:invalid_output_mode, String.t()}}
  def resolve_output_mode(options) do
    case Keyword.get(options, :output_mode, "native") do
      "native" -> {:ok, :native}
      "web-component" -> {:ok, :web_component}
      invalid -> {:error, {:invalid_output_mode, invalid}}
    end
  end

  @spec generate([Path.t()], String.t(), output_mode()) :: {:ok, [Path.t()]} | {:error, reason()}
  def generate(json_translations_path, module_name, output_mode \\ :native) do
    with {:ok, raw_translations} <- FileSystem.read_json_files(json_translations_path),
         {:ok, translations} <- Parser.parse_translations(raw_translations),
         {:ok, printed_translations} <- print_i18n_modules(translations, module_name, output_mode) do
      Result.traverse(printed_translations, fn {file_path, file_content} ->
        FileSystem.write_file(file_path, file_content)
      end)
    end
  end

  @spec print_i18n_modules([I18nResource.t()], String.t(), output_mode()) ::
          {:ok, [Printer.printed_file()]} | {:error, reason()}
  defp print_i18n_modules(translations, module_name, output_mode) do
    case Enum.find(translations, &I18nResource.reference?/1) do
      nil ->
        {:error, :missing_reference_translation}

      reference_translation ->
        case output_mode do
          :native ->
            {:ok, Printer.print_native_modules(translations, reference_translation, module_name)}

          :web_component ->
            {:ok,
             Printer.print_web_component_modules(translations, reference_translation, module_name)}
        end
    end
  end
end
