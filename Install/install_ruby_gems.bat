@echo off
REM Install the ruby gems.  Use call because gem is a batch file itself
echo Installing rubyXL gem
call gem install nokogiri -v 1.9.1
call gem install rubyXL
