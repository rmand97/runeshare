defmodule Runeshare.Sharing.DiscordWatchdogAlarms.FindersTest do
  use ExUnit.Case, async: true

  alias Runeshare.Sharing.DiscordWatchdogAlarms.{CodeBlocks, InlineJson}

  describe "InlineJson" do
    test "finds objects anywhere in the text, ignoring braces inside strings" do
      text = ~S(Here: {"a":"}{","b":{"c":1}} and {"d":2} plus a stray { brace)

      assert InlineJson.objects(text) == [~S({"a":"}{","b":{"c":1}}), ~S({"d":2})]
    end

    test "skips objects inside code blocks, which CodeBlocks reads" do
      message = %{"content" => "```json\n{\"in\":1}\n``` and {\"out\":2}"}

      assert InlineJson.exports(message) == [~S({"out":2})]
      assert CodeBlocks.exports(message) == [~s({"in":1}\n)]
    end
  end
end
