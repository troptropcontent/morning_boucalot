unless Rails.env.development?
  puts "Seeds are only run in development, skipping."
else
  unless User.exists?
    user = User.create!(email_address: "test@example.com", password: "password", password_confirmation: "password")

    fixture_image = Rails.root.join("spec/fixtures/files/test_image.jpg")

    [
      { title: "Golden hour", camera_model: "Sony A7 IV", focal_length: 85, aperture: 1.8, iso: 400, taken_at: 3.days.ago },
      { title: "Mountain trail", camera_model: "Sony A7 IV", focal_length: 24, aperture: 8.0, iso: 100, taken_at: 1.week.ago },
      { title: "City lights", camera_model: "Sony A7 IV", focal_length: 35, aperture: 2.0, iso: 3200, taken_at: 2.weeks.ago }
    ].each do |attrs|
      photo = user.photos.build(attrs)
      photo.file.attach(io: File.open(fixture_image), filename: "#{attrs[:title].parameterize}.jpg", content_type: "image/jpeg")
      photo.save!
    end

    puts "Seeded: 1 user (test@example.com / password), #{user.photos.count} photos"
  else
    puts "Database already seeded, skipping."
  end
end
