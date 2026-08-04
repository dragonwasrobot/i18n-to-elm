defmodule I18n2Elm.Domain.PrinterViews do
  @moduledoc """
  Defines the printer's per-template view structs, one per EEx template
  under `priv/templates/`.
  """

  defmodule LanguageView do
    @moduledoc """
    Template input for a single language's Elm translation module
    (`language.elm.eex`).
    """

    use TypedStruct

    typedstruct do
      field :file_name, String.t(), enforce: true
      field :translation_name, String.t(), enforce: true
      field :translation_pairs, [{String.t(), String.t()}], enforce: true
    end

    @spec new(String.t(), String.t(), [{String.t(), String.t()}]) :: t()
    def new(file_name, translation_name, translation_pairs) do
      %__MODULE__{
        file_name: file_name,
        translation_name: translation_name,
        translation_pairs: translation_pairs
      }
    end
  end

  defmodule IdsView do
    @moduledoc """
    Template input for the shared `TranslationId` union type module
    (`ids.elm.eex`).
    """

    use TypedStruct

    typedstruct do
      field :ids, [String.t()], enforce: true
    end

    @spec new([String.t()]) :: t()
    def new(ids) do
      %__MODULE__{ids: ids}
    end
  end

  defmodule UtilView do
    @moduledoc """
    Template input for the `Language` union type and the
    `parseLanguage`/`translate` dispatch functions (`util.elm.eex`).
    """

    use TypedStruct

    @type import_entry :: %{file_name: String.t(), translation_name: String.t()}
    @type language_entry :: %{
            string_value: String.t(),
            type_value: String.t(),
            translation_fun: String.t()
          }

    typedstruct do
      field :imports, [import_entry()], enforce: true
      field :languages, [language_entry()], enforce: true
    end

    @spec new([import_entry()], [language_entry()]) :: t()
    def new(imports, languages) do
      %__MODULE__{imports: imports, languages: languages}
    end
  end
end
