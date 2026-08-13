defmodule I18n2Elm.Domain.Printer.UtilView do
  @moduledoc """
  Template input for the `Language` union type and the
  `parseLanguage`/`translate` dispatch functions
  (`priv/templates/util.elm.eex`).
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
