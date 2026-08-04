defmodule I18n2ElmTest.Locale do
  use ExUnit.Case, async: true

  alias I18n2Elm.Domain.Locale

  doctest Locale

  test "should reject a locale with an empty language or country segment" do
    # Given a locale with an empty country segment
    raw_locale = "en_"

    # When parsing it
    result = Locale.parse(raw_locale)

    # Then parsing fails, naming the offending locale
    assert {:error, {:invalid_locale, "en_"}} = result
  end
end
