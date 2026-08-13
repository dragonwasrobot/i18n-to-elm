defmodule I18n2Elm.Domain.Printer.LanguageView do
  @moduledoc """
  Template input for a single language's Elm translation module
  (`priv/templates/language.elm.eex`).
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
