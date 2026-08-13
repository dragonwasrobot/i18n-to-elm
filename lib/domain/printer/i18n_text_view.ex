defmodule I18n2Elm.Domain.Printer.I18nTextView do
  @moduledoc """
  Template input for the `web-component` mode's single dispatch module
  (`priv/templates/i18n_text.elm.eex`).
  """

  use TypedStruct

  # One clause of the generated `tidToKey`/`tidToValues` Elm case expressions:
  # - The `TranslationId` pattern to match.
  # - The raw key text to return.
  # - The `List String` values expression to return.
  @type clause :: %{pattern: String.t(), key: String.t(), values_expr: String.t()}

  typedstruct do
    field :clauses, [clause()], enforce: true
  end

  @spec new([clause()]) :: t()
  def new(clauses) do
    %__MODULE__{clauses: clauses}
  end
end
