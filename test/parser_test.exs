defmodule I18n2ElmTest.Parser do
  use ExUnit.Case
  alias I18n2Elm.Parser
  alias I18n2Elm.Types.Translation

  test "parse daDk.json file" do

    parsed_translation =
      ~S"""
      {
        "Yes": "Ja",
        "No": "Nej",
        "Next": "Næste",
        "Previous": "Forrige"
      }
      """
      |> Poison.decode!()
      |> Parser.parse_translation("da_DK")

    expected_parsed_translation = %Translation{
      language_tag: "da_DK",
      translations: [
        {"TidNext", "Næste"},
        {"TidNo", "Nej"},
        {"TidPrevious", "Forrige"},
        {"TidYes", "Ja"}
      ]
    }

    assert parsed_translation == expected_parsed_translation
  end

end
