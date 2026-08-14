# Where a signed-in visitor's gallery landing page should point: a member
# always lands on their own gallery, but a guest has no photos of their own,
# so they land on the app's member gallery instead. Quick patch for the
# single-member case this app is currently built for — picking "first" would
# need revisiting if multiple members ever coexist.
class FindDefaultGalleryOwnerForUser < ApplicationService
  def initialize(user:)
    @user = user
  end

  def call
    @user.member? ? @user : User.member.first
  end
end
