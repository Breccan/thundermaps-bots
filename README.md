thundermaps-bots
================

Scripts and bots plugged to thundermaps

Simple test
===========
step 1: grab a Key
------------------
To grab a key, create an account on thundermaps.com then jump to http://thundermaps.com/for-developers/

step 2: put your
----------------
Since you have your key, you can use simple_test.rb to process at your simple test.

- edit simple_test.rb
- change key at top of document
- save it

step 3: test it in console
--------------------------
  sudo gem install 'httparty'
  ruby simple_test.rb

step 4: check result
--------------------

If you obtain `nil`, go to check at http://app.thundermaps.com/accounts/test your report is arrived. Congrat !

Else if is not arrived, probably `library_name` is wrong.

Also you can obtain something else than `nil`, you must obtain an html page. And somewhere a login page, `404` or `500` error.
