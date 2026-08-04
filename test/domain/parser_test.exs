defmodule I18n2ElmTest.Parser do
  use ExUnit.Case, async: true

  alias I18n2Elm.Domain.I18nResource
  alias I18n2Elm.Domain.Locale
  alias I18n2Elm.Domain.Parser

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

    # When parsing it for the da_DK locale
    {:ok, parsed_translation} = json |> Jason.decode!() |> Parser.parse_translation("da_DK")

    # Then each value is split into tagged text/hole tokens, keys unprefixed
    expected_parsed_translation = %I18nResource{
      locale: %Locale{language: "da", country: "DK"},
      translation_pairs: [
        {"Hello",
         [{:text, "Hej, "}, {:hole, 1}, {:text, ". Leder du efter "}, {:hole, 0}, {:text, "?"}]},
        {"Next", [{:text, "Næste"}]},
        {"No", [{:text, "Nej"}]},
        {"Previous", [{:text, "Forrige"}]},
        {"Yes", [{:text, "Ja"}]}
      ]
    }

    assert parsed_translation == expected_parsed_translation
  end

  test "should parse a translation value with holes at both the start and the end" do
    # Given a translation value with holes at both the start and the end
    json = ~S"""
    {"Hello": "{0} mid {1}"}
    """

    # When parsing it for the da_DK locale
    {:ok, parsed_translation} = json |> Jason.decode!() |> Parser.parse_translation("da_DK")

    # Then the value is split into tagged text/hole tokens, with no token for
    # the absent boundary text
    assert parsed_translation == %I18nResource{
             locale: %Locale{language: "da", country: "DK"},
             translation_pairs: [{"Hello", [{:hole, 0}, {:text, " mid "}, {:hole, 1}]}]
           }
  end

  test "should reject a translation value with non-contiguous hole numbering" do
    # Given a translation value whose hole numbers skip from 0 straight to 2
    json = ~S"""
    {"Hello": "Hej, {0}. Leder du efter {2}?"}
    """

    # When parsing it for the da_DK locale
    result = json |> Jason.decode!() |> Parser.parse_translation("da_DK")

    # Then parsing fails, naming the offending translation ID
    assert {:error, {:invalid_hole_numbering, "Hello"}} = result
  end

  test "should reject a translation value that reuses the same hole number twice" do
    # Given a translation value where hole {0} appears twice
    json = ~S"""
    {"Hello": "Hej, {0}. Leder du efter {0}?"}
    """

    # When parsing it for the da_DK locale
    result = json |> Jason.decode!() |> Parser.parse_translation("da_DK")

    # Then parsing fails, naming the offending translation ID
    assert {:error, {:invalid_hole_numbering, "Hello"}} = result
  end

  test "should reject a translation value with a non-numeric hole placeholder" do
    # Given a translation value whose `{N}`-style placeholder isn't a number
    json = ~S"""
    {"Hello": "Hej, {abc}?"}
    """

    # When parsing it for the da_DK locale
    result = json |> Jason.decode!() |> Parser.parse_translation("da_DK")

    # Then parsing fails, naming the offending translation ID
    assert {:error, {:invalid_hole_placeholder, "Hello"}} = result
  end

  test "should reject a translation whose locale isn't a language/country pair" do
    # Given a locale with no `_`-separated country component
    json = ~S"""
    {"Hello": "Hello"}
    """

    # When parsing it for that malformed locale
    result = json |> Jason.decode!() |> Parser.parse_translation("english")

    # Then parsing fails, naming the offending locale
    assert {:error, {:invalid_locale, "english"}} = result
  end
end
