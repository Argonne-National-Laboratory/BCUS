@echo off
REM Install the ruby gems.  Use call because gem is a batch file itself
REM Need to install nokogiri v 1.6.8.1 first because it's the last version that works with ruby 2.0.0
REM but works with all current versions of rubyXL
echo Installing nokogiri v1.6.8.1 and rubyXL
REM call gem install nokogiri -v 1.6.8.1
call gem install rubyXL

