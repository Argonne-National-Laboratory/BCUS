@echo off
REM Install the ruby gems.  Use call because gem is a batch file itself
echo Installing nokogiri v1.9.1, rubyXL, rinruby, parallel, and ruby-progressbar
call gem install nokogiri -v 1.9.1
call gem install rubyXL
call gem install rinruby
call gem install parallel
call gem install ruby-progressbar
