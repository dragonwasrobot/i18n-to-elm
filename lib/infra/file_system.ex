defmodule I18n2Elm.Infra.FileSystem do
  @moduledoc """
  Filesystem boundary: resolving paths to JSON files, reading and JSON-decoding
  these, and writing generated files back to disk. Decoded file contents are
  handed back raw (filename plus JSON map).
  """

  require Logger
  alias I18n2Elm.Result

  @type reason ::
          File.posix()
          | Jason.DecodeError.t()
          | {:no_files, [Path.t()]}

  @doc """
  Resolves `paths` to a non-empty list of JSON files, recursing into
  directories. Fails with `{:no_files, paths}` rather than returning `[]`,
  so callers never have to separately check for an empty result.
  """
  @spec resolve_all_paths([Path.t()]) :: {:ok, [Path.t()]} | {:error, reason()}
  def resolve_all_paths(paths) do
    existing_paths = Enum.filter(paths, &existing_path?/1)

    with {:ok, expanded} <- Result.traverse(existing_paths, &expand_path/1) do
      files = List.flatten(expanded)
      Logger.debug("Files: #{inspect(files)}")

      case files do
        [] -> {:error, {:no_files, paths}}
        _ -> {:ok, files}
      end
    end
  end

  @spec existing_path?(Path.t()) :: boolean()
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

  @spec read_json_files([Path.t()]) :: {:ok, [{String.t(), map()}]} | {:error, reason()}
  def read_json_files(paths), do: Result.traverse(paths, &read_json_file/1)

  @spec read_json_file(Path.t()) :: {:ok, {String.t(), map()}} | {:error, reason()}
  defp read_json_file(path) do
    filename = Path.basename(path, ".json")

    with {:ok, contents} <- File.read(path),
         {:ok, decoded} <- Jason.decode(contents) do
      {:ok, {filename, decoded}}
    end
  end

  @spec create_output_dir(list) :: {:ok, Path.t()} | {:error, File.posix()}
  def create_output_dir(options) do
    output_path = Keyword.get(options, :module_name, "Translations")

    with :ok <- File.mkdir_p(output_path) do
      {:ok, output_path}
    end
  end

  @spec write_file(Path.t(), String.t()) :: {:ok, Path.t()} | {:error, File.posix()}
  def write_file(file_path, file_content) do
    with {:ok, file} <- File.open(file_path, [:write]),
         :ok <- IO.binwrite(file, file_content),
         :ok <- File.close(file) do
      Logger.info("Created file: #{file_path}")
      {:ok, file_path}
    end
  end
end
