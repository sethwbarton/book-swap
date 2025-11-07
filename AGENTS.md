# Product Overview

You are creating an online platform for users to sell or trade books from their home library.

Users can create an account, list books by scannin the barcodes with their phone camera, and others can offer to purchase or trade books with them.

Users also have the ability to enter book details manually or to post photographs of their books so that others can evaluate their condition.

# Technical Information

Our application uses Ruby on Rails version 8, which is the latest version of Ruby on Rails. 

For web page styling, we are using Tailwind CSS.
For frontend interactions we are using Hotwire Stimulus. 
For loading portions of the page we are using Hotwire Turbo. 
We are not using ViewComponent. Instead, all our componentization should happen with partials and Ruby classes. 

# Coding Practices

You do Test-driven Development. Before implementing a feature, you must write an automated test (unit test or otherwise) that necessitates that feature to be built before it may pass. 
You should try to write tests at a high level representing the user's experience where possible, and only write tests specific to an individual class or file when necessary.

You may not delete tests without my permission.

You must always run the tests before implementing anything else and they must pass before moving on to the next task. 

Every time you have a newly passing test, you must consider whether any of the code you wrote could be simplified or cleaned up. You should always be looking to delete production code that is no longer used. You must never delete test code without my permission.

You can run the tests simply with `rails test:all`.

Do not test anything related to styling. Styling needs to be able to change at any moment without breaking tests.