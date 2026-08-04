defmodule I18n2Elm do
  @moduledoc ~S"""
  Transforms a folder of i18n key/value JSON files into a series of Elm types
  and functions.

  Expects a PATH to one or more JSON files from which to generate Elm code.

      i18n2elm PATH [--module-name PATH]

  The JSON files at the given PATH will be converted to Elm types and functions.

  ## Options

      * `--module-name` - the module name prefix for the printed Elm modules
      default value is 'Translations'.
  """

  require Logger
  alias I18n2Elm.Domain.{Parser, Printer}
  alias I18n2Elm.Infra.{CLI, FileSystem}
  alias I18n2Elm.Result

  @type reason ::
          FileSystem.reason()
          | Parser.reason()
          | Printer.reason()

  @spec main([String.t()]) :: no_return
  def main(args) do
    Logger.debug("Arguments: #{inspect(args)}")

    with {:ok, paths, options} <- CLI.parse_args(args),
         {:ok, files} <- FileSystem.resolve_all_paths(paths),
         {:ok, module_name} <- FileSystem.create_output_dir(options),
         {:ok, written_files} <- generate(files, module_name) do
      Logger.debug("Written files: #{inspect(written_files)}")
      exit(:normal)
    else
      {:error, :no_paths_given} ->
        IO.puts(@moduledoc)
        exit(:normal)

      {:error, {:unknown_arguments, errors}} ->
        Logger.error("Found one or more errors in the supplied options: #{inspect(errors)}")
        exit({:unknown_arguments, errors})

      {:error, {:no_files, paths}} ->
        Logger.error("Could not find any JSON files in path: #{inspect(paths)}")
        exit(:no_files)

      {:error, reason} ->
        Logger.error(inspect(reason))
        exit(reason)
    end
  end

  @spec generate([Path.t()], String.t()) :: {:ok, [Path.t()]} | {:error, reason()}
  def generate(json_translations_path, module_name) do
    with {:ok, raw_translations} <- FileSystem.read_json_files(json_translations_path),
         {:ok, translations} <- Parser.parse_translations(raw_translations),
         {:ok, printed_translations} <- Printer.print_elm_i18n_modules(translations, module_name) do
      Result.traverse(printed_translations, fn {file_path, file_content} ->
        FileSystem.write_file(file_path, file_content)
      end)
    end
  end
end
