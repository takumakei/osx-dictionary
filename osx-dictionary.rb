require "formula"

class OsxDictionary < Formula
  desc "CLI for OSX Dictionary"
  homepage "https://github.com/takumakei/osx-dictionary"

  head "https://github.com/takumakei/osx-dictionary.git", :branch => "master"

  depends_on "cmake" => :build

  def install
    mkdir "build" do
      system "cmake", "..", *std_cmake_args
      system "make", "install"
    end
  end
end
