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
          {"TidHello", [{"Hej, ", 1}, {". Leder du efter ", 0}, {"?"}]},
          {"TidNext", [{"Næste"}]},
          {"TidNo", [{"Nej"}]},
          {"TidPrevious", [{"Forrige"}]},
          {"TidYes", [{"Ja"}]}
        ]
      },
      %Translation{
        language_tag: "en_US",
        translations: [
          {"TidHello", [{"Hello, ", 0}, {"It is ", 1}, {"you are looking for?"}]},
          {"TidNext", [{"Next"}]},
          {"TidNo", [{"No"}]},
          {"TidPrevious", [{"Previous"}]},
          {"TidYes", [{"Yes"}]}
        ]
      }
    ]

    printed_translations = Printer.print_translations(translations, "Translations")

    Logger.debug(fn -> "#{inspect(printed_translations)}" end)

    assert true
  end
end
