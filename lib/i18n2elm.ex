defmodule I18n2Elm do
  @moduledoc ~S"""
  Transforms a folder of i18n key/value JSON files into a series of Elm types \
  and functions.

  Expects a PATH to one or more JSON files from which to generate Elm code.

      i18n2elm PATH [--module-name PATH]

  The JSON files at the given PATH will be converted to Elm types and functions.

  ## Options

      * `--module-name` - the module name prefix for the printed Elm modules \
      default value is 'Translations'.
  """

  require Logger
  alias I18n2Elm.{Parser, Printer}

  @spec main([String.t()]) :: :ok
  def main(args) do
    Logger.debug(fn -> "Arguments: #{inspect(args)}" end)

    {options, paths, errors} = OptionParser.parse(args, strict: [module_name: :string])

    if Enum.empty?(paths) do
      IO.puts(@moduledoc)
      exit(:normal)
    end

    if length(errors) > 0 do
      IO.puts("Error: Found one or more errors in the supplied options")
      exit({:unknown_arguments, errors})
    end

    files = resolve_all_paths(paths)
    Logger.debug(fn -> "Files: #{inspect(files)}" end)

    if Enum.empty?(files) do
      IO.puts("Error: Could not find any JSON files in path: #{inspect(paths)}")
      exit(:no_files)
    end

    output_path = create_output_dir(options)
    generate(files, output_path)
  end

  @spec resolve_all_paths([String.t()]) :: [String.t()]
  defp resolve_all_paths(paths) do
    paths
    |> Enum.filter(&File.exists?/1)
    |> Enum.reduce([], fn filename, files ->
      cond do
        File.dir?(filename) ->
          walk_directory(filename) ++ files

        String.ends_with?(filename, ".json") ->
          [filename | files]

        true ->
          files
      end
    end)
  end

  @spec walk_directory(String.t()) :: [String.t()]
  defp walk_directory(dir) do
    dir
    |> File.ls!()
    |> Enum.reduce([], fn file, files ->
      filename = "#{dir}/#{file}"

      cond do
        File.dir?(filename) ->
          walk_directory(filename) ++ files

        String.ends_with?(file, ".json") ->
          [filename | files]

        true ->
          files
      end
    end)
  end

  @spec create_output_dir(list) :: String.t()
  defp create_output_dir(options) do
    output_path =
      if Keyword.has_key?(options, :module_name) do
        Keyword.get(options, :module_name)
      else
        "Translations"
      end

    output_path
    |> File.mkdir_p!()

    output_path
  end

  @spec generate([String.t()], String.t()) :: :ok
  def generate(json_translations_path, module_name) do
    translations = Parser.parse_translation_files(json_translations_path)
    printed_translations = Printer.print_translations(translations, module_name)

    printed_translations
    |> Enum.each(fn {file_path, file_content} ->
      {:ok, file} = File.open(file_path, [:write])
      IO.binwrite(file, file_content)
      File.close(file)
      Logger.info("Created file: #{file_path}")
    end)
  end
end
