require 'tmpdir'
require 'fileutils'

describe Solargraph::ApiMap::BundlerMethods do
  after :each do
    Solargraph::ApiMap::BundlerMethods.reset_require_from_bundle
  end

  describe 'with Gemfile.lock' do
    before :all do
      Bundler.with_clean_env do
        `cd spec/fixtures/workspace && bundle install`
      end
    end

    after :all do
      File.unlink 'spec/fixtures/workspace/Gemfile.lock'
    end

    it 'finds default gems from bundler/require' do
      result = Solargraph::ApiMap::BundlerMethods.require_from_bundle('spec/fixtures/workspace')
      expect(result).to eq(['backport', 'bundler'])
    end
  end

  describe 'without Gemfile.lock' do
    it 'does not raise an error without a bundle' do
      expect {
        Dir.mktmpdir do |dir|
          Bundler.with_clean_env do
            Solargraph::ApiMap::BundlerMethods.require_from_bundle(dir)
          end
        end
      }.not_to raise_error
    end
  end
end