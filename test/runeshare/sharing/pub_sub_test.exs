defmodule Runeshare.Sharing.PubSubTest do
  use Runeshare.DataCase, async: true

  alias Phoenix.Socket.Broadcast
  alias Runeshare.Sharing

  test "subscribe_to_kind/1 hears shares and deletions of that kind only" do
    author = register_user!()
    :ok = Sharing.subscribe_to_kind(:tile_marker)

    marker = share_preset!(author, %{kind: :tile_marker})
    share_preset!(author, %{kind: :watchdog_alarm})
    Sharing.delete_preset!(marker, actor: author)

    marker_id = marker.id

    assert_receive %Broadcast{
      topic: "presets:shared:tile_marker",
      payload: %{data: %{id: ^marker_id}}
    }

    assert_receive %Broadcast{topic: "presets:deleted:tile_marker", event: "destroy"}
    refute_receive %Broadcast{topic: "presets:shared:watchdog_alarm"}
  end

  test "subscribe_to_preset/1 hears the preset, its likes and its comments" do
    author = register_user!()
    preset = share_preset!(author)
    :ok = Sharing.subscribe_to_preset(preset.id)

    Sharing.edit_preset!(preset, %{title: "Renamed"}, actor: author)
    Sharing.like_preset!(preset.id, actor: register_user!())
    Sharing.post_comment!(preset.id, "nice", actor: register_user!())

    topics = for _n <- 1..3, do: receive_topic()

    assert Enum.sort(topics) ==
             Enum.sort(~w(presets likes comments) |> Enum.map(&"#{&1}:#{preset.id}"))
  end

  test "unsubscribe_from_preset/1 stops all of them" do
    author = register_user!()
    preset = share_preset!(author)
    :ok = Sharing.subscribe_to_preset(preset.id)
    :ok = Sharing.unsubscribe_from_preset(preset.id)

    Sharing.edit_preset!(preset, %{title: "Renamed"}, actor: author)
    Sharing.like_preset!(preset.id, actor: register_user!())

    refute_receive %Broadcast{}
  end

  defp receive_topic do
    assert_receive %Broadcast{topic: topic}
    topic
  end
end
