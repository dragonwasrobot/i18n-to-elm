defmodule I18n2ElmTest.E2E do
  use ExUnit.Case

  test "should generate an Elm file per language plus Ids and Util modules on disk" do
    # Given real en_US and da_DK translation files on disk
    input_dir =
      Path.join(System.tmp_dir!(), "i18n2elm_e2e_#{System.unique_integer([:positive])}")

    File.mkdir_p!(input_dir)
    en_us_path = Path.join(input_dir, "en_US.json")
    da_dk_path = Path.join(input_dir, "da_DK.json")
    File.write!(en_us_path, ~S({"Hello": "Hello, {0}!", "Yes": "Yes"}))
    File.write!(da_dk_path, ~S({"Hello": "Hej, {0}!", "Yes": "Ja"}))

    output_dir =
      Path.join(System.tmp_dir!(), "i18n2elm_e2e_out_#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(output_dir, "Translations"))

    # When generating Elm code from those files
    result =
      File.cd!(output_dir, fn ->
        I18n2Elm.generate([en_us_path, da_dk_path], "Translations")
      end)

    # Then generation succeeds and each expected file exists on disk with real content
    assert {:ok, written_files} = result
    assert length(written_files) == 4

    en_us_elm = File.read!(Path.join(output_dir, "Translations/EnUs.elm"))
    assert en_us_elm =~ "module Translations.EnUs exposing (enUsTranslations)"
    assert en_us_elm =~ ~S("Hello, " ++ hole0 ++ "!")

    da_dk_elm = File.read!(Path.join(output_dir, "Translations/DaDk.elm"))
    assert da_dk_elm =~ "module Translations.DaDk exposing (daDkTranslations)"
    assert da_dk_elm =~ ~S("Hej, " ++ hole0 ++ "!")

    ids_elm = File.read!(Path.join(output_dir, "Translations/Ids.elm"))
    assert ids_elm =~ "type TranslationId"
    assert ids_elm =~ "TidHello String"
    assert ids_elm =~ "TidYes"

    util_elm = File.read!(Path.join(output_dir, "Translations/Util.elm"))
    assert util_elm =~ "type Language"
    assert util_elm =~ "DA_DK"
    assert util_elm =~ "EN_US"

    File.rm_rf!(input_dir)
    File.rm_rf!(output_dir)
  end
end
