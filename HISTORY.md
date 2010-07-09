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

