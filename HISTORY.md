## 0.9.13 (2010-09-1)

* Feedback bug fix

## 0.9.12 (2010-08-31)

* Bug fix

## 0.9.11 (2010-08-31)

* Added version 2 of the push protocol
* Loads of bug fixes for conditions around broken pipes

## 0.9.9 (2010-08-10)

* Changed the module from ResqueAps to Resque::Plugins::Aps, per Resque documentation

## 0.9.8 (2010-08-08)

* Fix a bug in the aps_read_error logging method.

## 0.9.7 (2010-07-26)

* Add a rake task to get the lengths of the application queues.

## 0.9.6 (2010-07-23)

* Fixed the revoked or expired exception identification code

## 0.9.5 (2010-07-08)

* Added Feedback class 

## 0.9.4 (2010-07-08)

* Use redis.[rpush,lpop,lrange] commands rather than Resque.[push,pop,peek] so that Resque queues are not created for the notifications.
* Add a rescue around create_sockets to transform the exception into an application exception before raising it.
* Fix the aps_application.erb table and link to the notifications.
* Fix the application test.

## 0.9.3 (2010-07-08)

* Remove the aps_application class attribute. It's Ruby monkey patch the Application class.

## 0.9.2 (2010-07-07)

* Change the version to fix the dependencies

## 0.9.1 (2010-07-07)

* Minor changes to ease Application use with other outside classes, including the future feedback class.

## 0.9.0 (2010-07-05)

* Initial code

