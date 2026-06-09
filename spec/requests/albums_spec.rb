require "rails_helper"

RSpec.describe "Albums", type: :request do
  let(:user) { FactoryBot.create(:user) }

  describe "GET /albums" do
    context "when not authenticated" do
      it "redirects to sign in" do
        get albums_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when authenticated" do
      before { sign_in(user) }

      it "returns 200" do
        get albums_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /albums/:id" do
    let(:album) { FactoryBot.create(:album, user: user) }

    before { sign_in(user) }

    it "returns 200" do
      get album_path(album)
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for another user's album" do
      other_album = FactoryBot.create(:album)
      get album_path(other_album)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /albums" do
    before { sign_in(user) }

    it "creates an album and redirects" do
      expect {
        post albums_path, params: { album: { title: "My Album" } }
      }.to change(Album, :count).by(1)

      expect(response).to redirect_to(Album.last)
    end

    it "renders new on failure" do
      post albums_path, params: { album: { title: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /albums/:id" do
    let(:album) { FactoryBot.create(:album, user: user) }

    before { sign_in(user) }

    it "updates and redirects" do
      patch album_path(album), params: { album: { title: "Updated" } }
      expect(response).to redirect_to(album)
      expect(album.reload.title).to eq("Updated")
    end
  end

  describe "DELETE /albums/:id" do
    let!(:album) { FactoryBot.create(:album, user: user) }

    before { sign_in(user) }

    it "destroys the album and redirects" do
      expect {
        delete album_path(album)
      }.to change(Album, :count).by(-1)

      expect(response).to redirect_to(albums_path)
    end
  end
end
