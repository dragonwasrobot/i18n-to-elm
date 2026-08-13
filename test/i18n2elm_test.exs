defmodule I18n2ElmTest do
  use ExUnit.Case

  alias I18n2Elm.Domain.Parser.Locale

  setup do
    module_name = "Translations"

    input_dir =
      Path.join(System.tmp_dir!(), "i18n2elm_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(input_dir)

    output_dir =
      Path.join(System.tmp_dir!(), "i18n2elm_test_out_#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(output_dir, module_name))

    on_exit(fn ->
      File.rm_rf!(input_dir)
      File.rm_rf!(output_dir)
    end)

    {:ok, module_name: module_name, input_dir: input_dir, output_dir: output_dir}
  end

  test "should resolve or reject output-mode as appropriate" do
    # Given options with --output-mode absent, set to "native", and set to
    # "web-component"
    absent = []
    native = [output_mode: "native"]
    web_component = [output_mode: "web-component"]
    invalid = [output_mode: "bogus"]

    # When resolving the output mode for each
    absent_result = I18n2Elm.resolve_output_mode(absent)
    native_result = I18n2Elm.resolve_output_mode(native)
    web_component_result = I18n2Elm.resolve_output_mode(web_component)
    invalid_result = I18n2Elm.resolve_output_mode(invalid)

    # Then it defaults to native mode, and otherwise the appropriate output mode
    assert {:ok, :native} = absent_result
    assert {:ok, :native} = native_result
    assert {:ok, :web_component} = web_component_result
    assert {:error, {:invalid_output_mode, "bogus"}} = invalid_result
  end

  test "should reject generation when missing reference translation", %{
    module_name: module_name,
    input_dir: input_dir
  } do
    # Given a real input file for a non-reference language
    da_dk_path = Path.join(input_dir, "da_DK.json")
    File.write!(da_dk_path, ~S({"Hello": "Hej"}))

    # When generating Elm code without the reference language among the inputs
    result = I18n2Elm.generate([da_dk_path], module_name)

    # Then generation fails, naming the missing reference language
    assert {:error, :missing_reference_translation} = result
  end

  test "should reject generation when a translation's key set differs", %{
    module_name: module_name,
    input_dir: input_dir,
    output_dir: output_dir
  } do
    # Given a reference-language file with two keys and a second file missing one of them
    en_us_path = Path.join(input_dir, "en_US.json")
    da_dk_path = Path.join(input_dir, "da_DK.json")
    File.write!(en_us_path, ~S({"Hello": "Hello", "Bye": "Bye"}))
    File.write!(da_dk_path, ~S({"Hello": "Hej"}))

    # When generating Elm code from that set
    result =
      File.cd!(output_dir, fn ->
        I18n2Elm.generate([en_us_path, da_dk_path], module_name)
      end)

    # Then generation fails, naming the file whose keys don't match
    assert {:error, {:mismatched_keys, %Locale{language: "da", country: "DK"}}} = result
  end
end
