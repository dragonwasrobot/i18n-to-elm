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
  alias I18n2Elm.Infra.CLI
  alias I18n2Elm.{Parser, Printer, Result, Types}
  alias I18n2Elm.Types.Translation

  @type reason ::
          File.posix()
          | Jason.DecodeError.t()
          | Parser.reason()
          | Printer.reason()
          | {:mismatched_keys, Types.language_tag()}

  @spec main([String.t()]) :: no_return
  def main(args) do
    Logger.debug("Arguments: #{inspect(args)}")

    with {:ok, paths, options} <- CLI.parse_args(args),
         {:ok, files} <- resolve_all_paths(paths),
         :ok <- validate_files_found(files, paths),
         {:ok, output_path} <- create_output_dir(options),
         {:ok, written_files} <- generate(files, output_path) do
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

  @spec resolve_all_paths([Path.t()]) :: {:ok, [Path.t()]} | {:error, File.posix()}
  defp resolve_all_paths(paths) do
    existing_paths = Enum.filter(paths, &existing_path?/1)

    with {:ok, expanded} <- Result.traverse(existing_paths, &expand_path/1) do
      {:ok, List.flatten(expanded)}
    end
  end

  @spec existing_path?(Path.t()) :: boolean
  defp existing_path?(path) do
    if File.exists?(path) do
      true
    else
      Logger.warning("Skipping nonexistent path: #{path}")
      false
    end
  end

  @spec expand_path(Path.t()) :: {:ok, [Path.t()]} | {:error, File.posix()}
  defp expand_path(path) do
    cond do
      File.dir?(path) ->
        with {:ok, entries} <- File.ls(path),
             {:ok, expanded} <- Result.traverse(entries, &expand_path(Path.join(path, &1))) do
          {:ok, List.flatten(expanded)}
        end

      String.ends_with?(path, ".json") ->
        {:ok, [path]}

      true ->
        Logger.warning("Skipping non-JSON path: #{path}")
        {:ok, []}
    end
  end

  @spec validate_files_found([Path.t()], [Path.t()]) ::
          :ok | {:error, {:no_files, [Path.t()]}}
  defp validate_files_found(files, paths) do
    Logger.debug("Files: #{inspect(files)}")

    case files do
      [] -> {:error, {:no_files, paths}}
      _ -> :ok
    end
  end

  @spec create_output_dir(list) :: {:ok, Path.t()} | {:error, File.posix()}
  defp create_output_dir(options) do
    output_path = Keyword.get(options, :module_name, "Translations")

    with :ok <- File.mkdir_p(output_path) do
      {:ok, output_path}
    end
  end

  @spec generate([Path.t()], String.t()) :: {:ok, [Path.t()]} | {:error, reason()}
  def generate(json_translations_path, module_name) do
    with {:ok, translations} <- read_translation_files(json_translations_path),
         :ok <- validate_reference_language_present(translations),
         :ok <- validate_matching_key_sets(translations),
         {:ok, printed_translations} <- Printer.print_translations(translations, module_name) do
      Result.traverse(printed_translations, fn {file_path, file_content} ->
        write_file(file_path, file_content)
      end)
    end
  end

  @spec validate_reference_language_present([Translation.t()]) ::
          :ok | {:error, :missing_reference_translation}
  defp validate_reference_language_present(translations) do
    if Enum.any?(translations, &reference_translation?/1) do
      :ok
    else
      {:error, :missing_reference_translation}
    end
  end

  @spec validate_matching_key_sets([Translation.t()]) ::
          :ok | {:error, {:mismatched_keys, Types.language_tag()}}
  defp validate_matching_key_sets(translations) do
    reference_keys =
      translations
      |> Enum.find(&reference_translation?/1)
      |> translation_keys()

    translations
    |> Enum.reject(&reference_translation?/1)
    |> Enum.find(&(not MapSet.equal?(translation_keys(&1), reference_keys)))
    |> case do
      nil -> :ok
      %Translation{language_tag: language_tag} -> {:error, {:mismatched_keys, language_tag}}
    end
  end

  @spec reference_translation?(Translation.t()) :: boolean
  defp reference_translation?(%Translation{language_tag: language_tag}) do
    language_tag == Types.reference_language_tag()
  end

  @spec translation_keys(Translation.t()) :: MapSet.t(String.t())
  defp translation_keys(%Translation{translations: translations}) do
    translations
    |> Enum.map(fn {translation_id, _hole_tokens} -> translation_id end)
    |> MapSet.new()
  end

  @spec write_file(Path.t(), String.t()) :: {:ok, Path.t()} | {:error, File.posix()}
  defp write_file(file_path, file_content) do
    with {:ok, file} <- File.open(file_path, [:write]),
         :ok <- IO.binwrite(file, file_content),
         :ok <- File.close(file) do
      Logger.info("Created file: #{file_path}")
      {:ok, file_path}
    end
  end

  @type read_reason :: File.posix() | Jason.DecodeError.t() | Parser.reason()

  @spec read_translation_files([Path.t()]) :: {:ok, [Translation.t()]} | {:error, read_reason()}
  defp read_translation_files(paths), do: Result.traverse(paths, &read_translation_file/1)

  @spec read_translation_file(Path.t()) :: {:ok, Translation.t()} | {:error, read_reason()}
  defp read_translation_file(translation_file_path) do
    language_tag = Path.basename(translation_file_path, ".json")

    with {:ok, contents} <- File.read(translation_file_path),
         {:ok, decoded} <- Jason.decode(contents) do
      Parser.parse_translation(decoded, language_tag)
    end
  end
end
