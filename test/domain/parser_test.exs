defmodule I18n2ElmTest.Parser do
  use ExUnit.Case, async: true

  alias I18n2Elm.Domain.Parser
  alias I18n2Elm.Domain.Types.Translation

  test "should parse a translation map into a translation struct" do
    # Given a translation map with plain values and one holed value
    json = ~S"""
    {
      "Yes": "Ja",
      "No": "Nej",
      "Next": "Næste",
      "Previous": "Forrige",
      "Hello": "Hej, {1}. Leder du efter {0}?"
    }
    """

    # When parsing it for the da_DK language tag
    {:ok, parsed_translation} = json |> Jason.decode!() |> Parser.parse_translation("da_DK")

    # Then each key is Tid-prefixed and each value is split into tagged text/hole tokens
    expected_parsed_translation = %Translation{
      language_tag: "da_DK",
      translations: [
        {"TidHello",
         [{:text, "Hej, "}, {:hole, 1}, {:text, ". Leder du efter "}, {:hole, 0}, {:text, "?"}]},
        {"TidNext", [{:text, "Næste"}]},
        {"TidNo", [{:text, "Nej"}]},
        {"TidPrevious", [{:text, "Forrige"}]},
        {"TidYes", [{:text, "Ja"}]}
      ]
    }

    assert parsed_translation == expected_parsed_translation
  end

  test "should parse a translation value with holes at both the start and the end" do
    # Given a translation value with holes at both the start and the end
    json = ~S"""
    {"Hello": "{0} mid {1}"}
    """

    # When parsing it for the da_DK language tag
    {:ok, parsed_translation} = json |> Jason.decode!() |> Parser.parse_translation("da_DK")

    # Then the value is split into tagged text/hole tokens, with no token for
    # the absent boundary text
    assert parsed_translation == %Translation{
             language_tag: "da_DK",
             translations: [{"TidHello", [{:hole, 0}, {:text, " mid "}, {:hole, 1}]}]
           }
  end

  test "should reject a translation value with non-contiguous hole numbering" do
    # Given a translation value whose hole numbers skip from 0 straight to 2
    json = ~S"""
    {"Hello": "Hej, {0}. Leder du efter {2}?"}
    """

    # When parsing it for the da_DK language tag
    result = json |> Jason.decode!() |> Parser.parse_translation("da_DK")

    # Then parsing fails, naming the offending translation ID
    assert {:error, {:invalid_hole_numbering, "TidHello"}} = result
  end

  test "should reject a translation value that reuses the same hole number twice" do
    # Given a translation value where hole {0} appears twice
    json = ~S"""
    {"Hello": "Hej, {0}. Leder du efter {0}?"}
    """

    # When parsing it for the da_DK language tag
    result = json |> Jason.decode!() |> Parser.parse_translation("da_DK")

    # Then parsing fails, naming the offending translation ID
    assert {:error, {:invalid_hole_numbering, "TidHello"}} = result
  end

  test "should reject a translation value with a non-numeric hole placeholder" do
    # Given a translation value whose `{N}`-style placeholder isn't a number
    json = ~S"""
    {"Hello": "Hej, {abc}?"}
    """

    # When parsing it for the da_DK language tag
    result = json |> Jason.decode!() |> Parser.parse_translation("da_DK")

    # Then parsing fails, naming the offending translation ID
    assert {:error, {:invalid_hole_placeholder, "TidHello"}} = result
  end
end
