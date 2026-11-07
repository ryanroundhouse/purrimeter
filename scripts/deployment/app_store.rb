# The Apple API/Transporter adapter. JSON requests arrive on stdin; credentials
# stay in owner-only files and never enter command-line arguments or logs.
ENV['FASTLANE_SKIP_UPDATE_CHECK'] = '1'
ENV['FASTLANE_HIDE_CHANGELOG'] = '1'
ENV['FASTLANE_OPT_OUT_USAGE'] = '1'
ENV['CI'] = '1'
require 'json'
require 'fastlane'
require 'deliver'
require 'spaceship'

request = JSON.parse(STDIN.read)
credentials = JSON.parse(File.read(request.fetch('credentials')))
key = {key_id: credentials.fetch('key_id'), issuer_id: credentials.fetch('issuer_id'),
       key: File.read(File.expand_path(credentials.fetch('key_file'))), in_house: false}
Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(**key)
app = Spaceship::ConnectAPI::App.get(app_id: request.fetch('app_id'))
raise 'Unexpected Apple app bundle ID' unless app.bundle_id == 'com.roundhouselabsinc.purrimeter'
version = request.fetch('version')
build_number = request.fetch('build_number', version)

def reply(value)
  puts "PURRIMETER_RESULT=#{JSON.generate(value)}"
end

case request.fetch('operation')
when 'status'
  builds = Spaceship::ConnectAPI::Build.all(app_id: app.id, version: version,
                                           build_number: build_number, platform: 'IOS')
  versions = app.get_app_store_versions(filter: {platform: 'IOS', versionString: version}, includes: 'build')
  current = versions.first
  inflight = app.get_in_progress_review_submission(platform: 'IOS', includes: 'items')
  reply({build: builds.first && {id: builds.first.id, state: builds.first.processing_state},
         version_id: current&.id, state: current&.app_store_state,
         selected_build: current&.build&.id, review_in_progress: !inflight.nil?})
when 'upload'
  # Only upload the exact IPA; metadata and submission have separate checkpoints.
  options = {api_key: key, app_identifier: app.bundle_id, app: app.id, app_version: version,
             ipa: request.fetch('ipa'), platform: 'ios', skip_metadata: true,
             metadata_path: File.join(File.dirname(request.fetch('ipa')), 'store/ios/metadata'),
             screenshots_path: File.join(File.dirname(request.fetch('ipa')), 'store/ios/screenshots'),
             skip_screenshots: true, skip_app_version_update: true,
             run_precheck_before_submit: false, submit_for_review: false, force: true}
  Deliver::Runner.new(FastlaneCore::Configuration.create(Deliver::Options.available_options, options)).run
  reply({uploaded: true})
when 'listing'
  listing = JSON.parse(File.read(File.join(request.fetch('listing'), 'listing.json')))
  locale = listing.fetch('locale')
  options = {api_key: key, app_identifier: app.bundle_id, app: app.id,
             app_version: version, platform: 'ios', skip_binary_upload: true,
             metadata_path: File.join(request.fetch('listing'), 'metadata'),
             screenshots_path: File.join(request.fetch('listing'), 'screenshots'),
             overwrite_screenshots: true, force: true, run_precheck_before_submit: false,
             name: {locale => listing.fetch('name')}, subtitle: {locale => listing.fetch('subtitle')},
             description: {locale => listing.fetch('description')}, keywords: {locale => listing.fetch('keywords')},
             support_url: {locale => listing.fetch('support_url')}, marketing_url: {locale => listing.fetch('marketing_url')},
             privacy_url: {locale => listing.fetch('privacy_url')},
             copyright: listing.fetch('copyright'), primary_category: 'GAMES',
             primary_first_sub_category: 'GAMES_STRATEGY', automatic_release: true,
             app_review_information: listing.fetch('review').transform_keys(&:to_sym).merge(phone_number: credentials.fetch('review_phone'))}
  # Apple's first version has no What's New field.
  live = app.get_live_app_store_version(platform: 'IOS')
  options[:release_notes] = {locale => File.read(File.join(request.fetch('listing'), 'release-notes.txt')).gsub('{version}', version)} if live
  Deliver::Runner.new(FastlaneCore::Configuration.create(Deliver::Options.available_options, options)).run
  reply({listing: true})
when 'submit'
  current = app.get_app_store_versions(filter: {platform: 'IOS', versionString: version}, includes: 'build').first
  raise 'App Store version is missing' unless current
  build = Spaceship::ConnectAPI::Build.all(app_id: app.id, version: version,
                                          build_number: build_number, platform: 'IOS').first
  raise 'Build is not processed and valid' unless build&.processing_state == 'VALID'
  current.select_build(build_id: build.id)
  # Resume a submission whose creation succeeded but whose response was lost.
  submission = app.get_ready_review_submission(platform: 'IOS', includes: 'items')
  submission ||= app.create_review_submission(platform: 'IOS')
  items = Spaceship::ConnectAPI::ReviewSubmissionItem.all(review_submission_id: submission.id,
                                                          includes: 'appStoreVersion')
  if items.empty?
    submission.add_app_store_version_to_review_items(app_store_version_id: current.id)
  else
    owned = items.length == 1 && items.first.app_store_version&.id == current.id
    raise 'Existing submission contains other items; inspect App Store Connect' unless owned
  end
  ready = false
  10.times do
    latest = Spaceship::ConnectAPI::AppStoreVersion.get(app_store_version_id: current.id)
    if latest.app_version_state == 'READY_FOR_REVIEW'
      ready = true
      break
    end
    puts 'App Store: waiting for the selected version to become ready for review…'
    sleep(15)
  end
  raise 'Apple has not made the version ready for review; retry the same release' unless ready
  submission.submit_for_review
  reply({submitted: true, submission_id: submission.id, build_id: build.id})
else
  raise 'Unknown operation'
end
