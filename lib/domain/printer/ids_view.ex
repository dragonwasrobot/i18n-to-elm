defmodule I18n2Elm.Domain.Printer.IdsView do
  @moduledoc """
  Template input for the shared `TranslationId` union type module
  (`priv/templates/ids.elm.eex`).
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
