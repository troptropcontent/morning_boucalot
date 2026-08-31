require "rails_helper"

RSpec.describe "Photos", type: :request do
  let(:user) { FactoryBot.create(:user) }

  describe "GET /:user_id/photos" do
    context "when not authenticated" do
      it "returns 200 for public access" do
        get user_photos_path(user)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when authenticated" do
      before { sign_in(user) }

      it "returns 200" do
        get user_photos_path(user)
        expect(response).to have_http_status(:ok)
      end

      it "shows the navbar's Upload link" do
        get user_photos_path(user)
        expect(response.body).to include("+ Upload")
      end
    end

    context "with tags among the owner's photos" do
      let!(:tagged_photo) { FactoryBot.create(:photo, user: user) }

      before { SyncPhotoTags.call(photo: tagged_photo, tag_list: "nature, travel") }

      it "renders a pill for each distinct tag" do
        get user_photos_path(user)
        expect(response.body).to include(">nature<")
        expect(response.body).to include(">travel<")
      end

      it "does not render the tag picker button when the owner has no tags" do
        get user_photos_path(FactoryBot.create(:user))
        expect(response.body).not_to include("tag-filter-modal")
      end

      context "when a tag is active" do
        it "shows a clear pill and highlights the Tags button" do
          get user_photos_path(user, tag: "nature")
          expect(response.body).to include("✕ nature")
          expect(response.body).not_to include(">nature<") # moved into the clear pill, not the pill list
        end
      end
    end
  end

  describe "GET /:user_id/photos/:id" do
    let(:photo) { FactoryBot.create(:photo, user: user) }

    it "returns 200 without authentication" do
      get user_photo_path(user, photo)
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for a photo belonging to a different user" do
      other_photo = FactoryBot.create(:photo)
      get user_photo_path(user, other_photo)
      expect(response).to have_http_status(:not_found)
    end

    context "with adjacent photos" do
      let!(:older_photo)  { FactoryBot.create(:photo, user: user, taken_at: 2.days.ago) }
      let!(:middle_photo) { FactoryBot.create(:photo, user: user, taken_at: 1.day.ago) }
      let!(:newer_photo)  { FactoryBot.create(:photo, user: user, taken_at: Time.current) }

      it "shows both arrows for a middle photo" do
        get user_photo_path(user, middle_photo)
        expect(response.body).to include(user_photo_path(user, newer_photo))
        expect(response.body).to include(user_photo_path(user, older_photo))
      end

      it "shows no prev arrow for the newest photo" do
        get user_photo_path(user, newer_photo)
        expect(response.body).not_to include("Previous photo")
        expect(response.body).to include(user_photo_path(user, middle_photo))
      end

      it "shows no next arrow for the oldest photo" do
        get user_photo_path(user, older_photo)
        expect(response.body).to include(user_photo_path(user, middle_photo))
        expect(response.body).not_to include("Next photo")
      end

      it "preloads the next photo's large variant when one exists" do
        get user_photo_path(user, middle_photo)
        expect(response.body).to include('data-controller="photo-preload"')
      end

      it "does not attempt to preload when there is no next photo" do
        get user_photo_path(user, older_photo)
        expect(response.body).not_to include('data-controller="photo-preload"')
      end
    end

    context "with tag filter" do
      let(:nature_tag) { FactoryBot.create(:tag, name: "nature") }
      let!(:tagged_older)  { FactoryBot.create(:photo, user: user, taken_at: 2.days.ago,   tags: [nature_tag]) }
      let!(:tagged_middle) { FactoryBot.create(:photo, user: user, taken_at: 1.day.ago,    tags: [nature_tag]) }
      let!(:tagged_newer)  { FactoryBot.create(:photo, user: user, taken_at: Time.current, tags: [nature_tag]) }
      let!(:untagged)      { FactoryBot.create(:photo, user: user, taken_at: 12.hours.ago) }

      it "navigates only within tagged photos" do
        get user_photo_path(user, tagged_middle, tag: "nature")
        expect(response.body).to include(user_photo_path(user, tagged_newer, tag: "nature"))
        expect(response.body).to include(user_photo_path(user, tagged_older, tag: "nature"))
        expect(response.body).not_to include(user_photo_path(user, untagged))
      end
    end

    context "with tags on the photo" do
      let(:photo) { FactoryBot.create(:photo, user: user) }

      before { SyncPhotoTags.call(photo: photo, tag_list: "nature, travel") }

      it "shows each tag as a link back to the filtered index" do
        get user_photo_path(user, photo)
        expect(response.body).to include(user_photos_path(user, tag: "nature"))
        expect(response.body).to include(user_photos_path(user, tag: "travel"))
      end

      it "breaks the tag links out of the photo_details turbo frame" do
        # Without this, Turbo tries to satisfy the click by finding a
        # matching #photo_details frame in the index page's response, finds
        # none, and the link silently does nothing instead of navigating.
        get user_photo_path(user, photo)
        tag_link = %r{<a[^>]*href="#{Regexp.escape(user_photos_path(user, tag: "nature"))}"[^>]*>}
        expect(response.body).to match(tag_link)
        expect(response.body[tag_link]).to include('data-turbo-frame="_top"')
      end
    end

    context "with favorited filter" do
      let!(:fav_older)  { FactoryBot.create(:photo, user: user, taken_at: 2.days.ago) }
      let!(:fav_middle) { FactoryBot.create(:photo, user: user, taken_at: 1.day.ago) }
      let!(:fav_newer)  { FactoryBot.create(:photo, user: user, taken_at: Time.current) }
      let!(:unfav)      { FactoryBot.create(:photo, user: user, taken_at: 12.hours.ago) }

      before do
        sign_in(user)
        [ fav_older, fav_middle, fav_newer ].each { |photo| FactoryBot.create(:favorite, user: user, photo: photo) }
      end

      it "navigates only within favorited photos" do
        get user_photo_path(user, fav_middle, favorited: "1")
        expect(response.body).to include(user_photo_path(user, fav_newer, favorited: "1"))
        expect(response.body).to include(user_photo_path(user, fav_older, favorited: "1"))
        expect(response.body).not_to include(user_photo_path(user, unfav))
      end
    end
  end

  describe "GET /:user_id/photos/new" do
    before { sign_in(user) }

    it "offers the owner's existing tags as suggestions" do
      tagged_photo = FactoryBot.create(:photo, user: user)
      SyncPhotoTags.call(photo: tagged_photo, tag_list: "nature")

      get new_user_photo_path(user)
      expect(response.body).to include('<option value="nature">')
    end
  end

  describe "POST /:user_id/photos" do
    before { sign_in(user) }

    let(:file) do
      Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/test_image.jpg"),
        "image/jpeg"
      )
    end

    it "creates a photo and redirects" do
      expect {
        post user_photos_path(user), params: { photo: { file: file, title: "Sunset" } }
      }.to change(Photo, :count).by(1)

      expect(response).to redirect_to(user_photo_path(user, Photo.last))
    end

    it "renders new on failure" do
      post user_photos_path(user), params: { photo: { title: "No file" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "still offers tag suggestions when re-rendering after a failure" do
      tagged_photo = FactoryBot.create(:photo, user: user)
      SyncPhotoTags.call(photo: tagged_photo, tag_list: "nature")

      post user_photos_path(user), params: { photo: { title: "No file" } }
      expect(response.body).to include('<option value="nature">')
    end

    it "returns 403 when posting to another user's scope" do
      other_user = FactoryBot.create(:user)
      post user_photos_path(other_user), params: { photo: { file: file, title: "Sunset" } }
      expect(response).to have_http_status(:forbidden)
    end

    context "with a duplicate file (JSON)" do
      before do
        post user_photos_path(user), params: { photo: { file: file } }
      end

      it "returns 200 with duplicate status" do
        duplicate_file = Rack::Test::UploadedFile.new(
          Rails.root.join("spec/fixtures/files/test_image.jpg"),
          "image/jpeg"
        )
        post user_photos_path(user),
          params: { photo: { file: duplicate_file } },
          headers: { "Accept" => "application/json" }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["status"]).to eq("duplicate")
      end

      it "does not create a new photo" do
        duplicate_file = Rack::Test::UploadedFile.new(
          Rails.root.join("spec/fixtures/files/test_image.jpg"),
          "image/jpeg"
        )
        expect {
          post user_photos_path(user), params: { photo: { file: duplicate_file } }
        }.not_to change(Photo, :count)
      end
    end
  end

  describe "PATCH /:user_id/photos/:id" do
    let(:photo) { FactoryBot.create(:photo, user: user) }

    before { sign_in(user) }

    it "updates and redirects" do
      patch user_photo_path(user, photo), params: { photo: { title: "Updated" } }
      expect(response).to redirect_to(user_photo_path(user, photo))
      expect(photo.reload.title).to eq("Updated")
    end
  end

  describe "DELETE /:user_id/photos/:id" do
    let!(:photo) { FactoryBot.create(:photo, user: user) }

    before { sign_in(user) }

    it "destroys the photo and redirects" do
      expect {
        delete user_photo_path(user, photo)
      }.to change(Photo, :count).by(-1)

      expect(response).to redirect_to(user_photos_path(user))
    end
  end

  describe "GET /:user_id/photos?favorited=1" do
    let!(:favorited_photo) { FactoryBot.create(:photo, user: user) }
    let!(:regular_photo)   { FactoryBot.create(:photo, user: user) }

    before do
      sign_in(user)
      FactoryBot.create(:favorite, user: user, photo: favorited_photo)
    end

    it "shows only favorited photos" do
      get user_photos_path(user, favorited: 1)
      expect(response.body).to include(user_photo_path(user, favorited_photo))
      expect(response.body).not_to include(user_photo_path(user, regular_photo))
    end

    it "marks the favorites toggle as active and links back to the unfiltered list" do
      get user_photos_path(user, favorited: 1)
      expect(response.body).to include(%(href="#{user_photos_path(user)}"))
      expect(response.body).to include('aria-pressed="true"')
    end

    it "shows an empty state when there are no favorites" do
      Favorite.destroy_all

      get user_photos_path(user, favorited: 1)
      expect(response.body).to include("No favorites yet.")
    end

    it "ignores the filter once signed out, instead of showing an empty gallery" do
      # `favorited` is scoped to Current.user; without a session there's no
      # "my favorites" to show. A visitor can land here with the param still
      # set — e.g. sign-out redirects back to the referring URL — so this
      # must show the full gallery, not a blank one that reads as "no photos".
      delete session_path

      get user_photos_path(user, favorited: 1)
      expect(response.body).to include(user_photo_path(user, favorited_photo))
      expect(response.body).to include(user_photo_path(user, regular_photo))
      expect(response.body).not_to include("No favorites yet.")
    end
  end

  describe "GET /:user_id/photos favorites toggle" do
    let!(:photo) { FactoryBot.create(:photo, user: user) }

    it "links to the favorited-only view and is inactive by default" do
      sign_in(user)
      get user_photos_path(user)
      expect(response.body).to include(user_photos_path(user, favorited: 1))
      expect(response.body).to include('aria-pressed="false"')
    end

    it "is hidden from unauthenticated visitors, since it has nothing to scope by" do
      get user_photos_path(user)
      expect(response.body).not_to include("Favorites")
    end
  end

  describe "PATCH /:user_id/photos/:id/favorite" do
    let(:photo) { FactoryBot.create(:photo, user: user) }

    context "when authenticated as the owner" do
      before { sign_in(user) }

      it "toggles favorited to true and responds with turbo stream" do
        patch favorite_user_photo_path(user, photo),
              headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("text/vnd.turbo-stream.html")
        expect(photo.favorited_by?(user)).to be true
      end

      it "toggles favorited back to false" do
        FactoryBot.create(:favorite, user: user, photo: photo)
        patch favorite_user_photo_path(user, photo),
              headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(photo.favorited_by?(user)).to be false
      end

      it "redirects on html format" do
        patch favorite_user_photo_path(user, photo)
        expect(response).to redirect_to(user_photo_path(user, photo))
      end
    end

    context "when authenticated as a different user" do
      it "favorites the photo for that user without touching the owner's favorites" do
        viewer = FactoryBot.create(:user)
        sign_in(viewer)

        patch favorite_user_photo_path(user, photo)

        expect(photo.favorited_by?(viewer)).to be true
        expect(photo.favorited_by?(user)).to be false
      end
    end

    context "when not authenticated" do
      it "does not favorite the photo and redirects to login on html format" do
        patch favorite_user_photo_path(user, photo)

        expect(photo.favorited_by?(user)).to be false
        expect(response).to redirect_to(new_session_path)
      end

      it "responds 401 and updates the flash in place on turbo stream requests, without redirecting" do
        patch favorite_user_photo_path(user, photo),
              headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:unauthorized)
        expect(response.content_type).to include("text/vnd.turbo-stream.html")
        expect(response.body).to include("You must be logged in to do that.")
      end
    end
  end

  describe "POST /:user_id/photos/download_zip" do
    let!(:photos) { FactoryBot.create_list(:photo, 2, user: user) }

    context "when authenticated as the owner" do
      before { sign_in(user) }

      it "returns a ZIP file containing the selected photos" do
        post download_zip_user_photos_path(user), params: { photo_ids: photos.map(&:id) }
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq("application/zip")
        expect(response.headers["Content-Disposition"]).to include("attachment")
        expect(response.headers["Content-Disposition"]).to include(".zip")
      end

      it "downloads the large variant when variant=large" do
        post download_zip_user_photos_path(user), params: { photo_ids: photos.map(&:id), variant: "large" }
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq("application/zip")
      end

      it "redirects with alert when no photo_ids are given" do
        post download_zip_user_photos_path(user), params: { photo_ids: [] }
        expect(response).to redirect_to(user_photos_path(user))
        expect(flash[:alert]).to be_present
      end

      it "returns 403 when targeting another user's scope" do
        other_user = FactoryBot.create(:user)
        post download_zip_user_photos_path(other_user), params: { photo_ids: photos.map(&:id) }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        post download_zip_user_photos_path(user), params: { photo_ids: photos.map(&:id) }
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe "PATCH /:user_id/photos/batch" do
    let!(:photos) { FactoryBot.create_list(:photo, 2, user: user) }

    context "when authenticated as the owner" do
      before { sign_in(user) }

      it "adds tags to the selected photos and redirects" do
        patch batch_user_photos_path(user), params: { photo_ids: photos.map(&:id), tag_list: "landscape" }
        expect(response).to redirect_to(user_photos_path(user))
        photos.each { |p| expect(p.reload.tags.map(&:name)).to include("landscape") }
      end

      it "returns 403 when targeting another user's scope" do
        other_user = FactoryBot.create(:user)
        patch batch_user_photos_path(other_user), params: { photo_ids: photos.map(&:id), tag_list: "landscape" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        patch batch_user_photos_path(user), params: { photo_ids: photos.map(&:id), tag_list: "landscape" }
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe "DELETE /:user_id/photos" do
    let!(:photos) { FactoryBot.create_list(:photo, 2, user: user) }

    context "when authenticated as the owner" do
      before { sign_in(user) }

      it "destroys the selected photos and redirects" do
        expect {
          delete user_photos_path(user), params: { photo_ids: photos.map(&:id) }
        }.to change(Photo, :count).by(-2)
        expect(response).to redirect_to(user_photos_path(user))
      end

      it "removes each deleted photo's card via turbo stream" do
        delete user_photos_path(user),
               params: { photo_ids: photos.map(&:id) },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        photos.each do |photo|
          expect(response.body).to include(%(target="photo_#{photo.id}"))
        end
      end

      it "leaves unselected photos of the owner untouched" do
        untouched = FactoryBot.create(:photo, user: user)
        delete user_photos_path(user), params: { photo_ids: [ photos.first.id ] }
        expect(Photo.exists?(untouched.id)).to be true
      end

      it "redirects with an alert when no photo_ids are given" do
        delete user_photos_path(user), params: { photo_ids: [] }
        expect(response).to redirect_to(user_photos_path(user))
        expect(flash[:alert]).to be_present
      end

      it "returns 403 when targeting another user's scope" do
        other_user = FactoryBot.create(:user)
        delete user_photos_path(other_user), params: { photo_ids: photos.map(&:id) }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        delete user_photos_path(user), params: { photo_ids: photos.map(&:id) }
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
