defmodule I18n2ElmTest.E2E do

  require Logger
  use ExUnit.Case
  alias I18n2Elm.Printer
  alias I18n2Elm.Types.Translation

  test "printed files" do

    translations = [
      %Translation{
        language_tag: "da_DK",
        translations: [
          {"TidNext", "Næste"},
          {"TidNo", "Nej"},
          {"TidPrevious", "Forrige"},
          {"TidYes", "Ja"}
        ]
      },

      %Translation{
        language_tag: "en_US",
        translations: [
          {"TidNext", "Next"},
          {"TidNo", "No"},
          {"TidPrevious", "Previous"},
          {"TidYes", "Yes"}
        ]
      }
    ]

    printed_translations = Printer.print_translations(translations, "Translations")

    Logger.debug "#{inspect printed_translations}"

    assert true
  end

end
