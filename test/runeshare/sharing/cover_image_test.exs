defmodule Runeshare.Sharing.CoverImageTest do
  use Runeshare.DataCase, async: true

  alias AshStorage.Service.Test, as: Store
  alias Runeshare.Sharing

  describe "cover image" do
    test "is stored on share, replaced on edit and removed on request" do
      author = register_user!()
      preset = share_preset!(author, %{cover_image: cover_image()})

      first_url = Sharing.get_preset!(preset.id).cover_image_url
      assert Store.exists?(key(first_url))

      Sharing.edit_preset!(preset, %{cover_image: cover_image()}, actor: author)
      second_url = Sharing.get_preset!(preset.id).cover_image_url
      assert second_url != first_url
      refute Store.exists?(key(first_url))

      Sharing.edit_preset!(preset, %{remove_cover_image: true}, actor: author)
      assert Sharing.get_preset!(preset.id).cover_image_url == nil
      refute Store.exists?(key(second_url))
    end

    test "changing only the image keeps the preset's version" do
      author = register_user!()
      preset = share_preset!(author)

      edited = Sharing.edit_preset!(preset, %{cover_image: cover_image()}, actor: author)

      assert edited.version == 1
    end

    test "is deleted with its preset" do
      author = register_user!()
      preset = share_preset!(author, %{cover_image: cover_image()})
      url = Sharing.get_preset!(preset.id).cover_image_url

      Sharing.delete_preset!(preset, actor: author)

      refute Store.exists?(key(url))
    end

    test "must really be an image of the declared type, at most 2 MB" do
      author = register_user!()
      png_header = <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A>>

      for upload <- [
            cover_image(temp_file!("<html>not an image</html>"), "image/png"),
            cover_image(cover_image_path(), "image/jpeg"),
            cover_image(temp_file!([png_header, :binary.copy(<<0>>, 2_000_001)]))
          ] do
        assert {:error, %Ash.Error.Invalid{}} =
                 Sharing.share_preset(
                   %{
                     kind: :watchdog_alarm,
                     title: "With a bad image",
                     content: watchdog_export(),
                     cover_image: upload
                   },
                   actor: author
                 )
      end
    end

    test "only the author can change it" do
      preset = share_preset!(register_user!())

      assert {:error, %Ash.Error.Forbidden{}} =
               Sharing.edit_preset(preset, %{cover_image: cover_image()}, actor: register_user!())
    end
  end

  defp key("http://test.local/storage/" <> key), do: key
end
