(defpackage :yason-test
  (:use :cl :unit-test))

(in-package :yason-test)

(defparameter *basic-test-json-string* "[{\"foo\":1,\"bar\":[7,8,9]},2,3,4,[5,6,7],true,null]")
(defparameter *basic-test-json-string-indented* "
[
  {\"foo\":1,
   \"bar\":[7,8,9]
  },
  2, 3, 4, [5, 6, 7], true, null
]")
(defparameter *basic-test-json-dom* (list (alexandria:plist-hash-table
                                           '("foo" 1 "bar" (7 8 9))
                                           :test #'equal)
                                          2 3 4
                                          '(5 6 7)
                                          t nil))
(defclass bar ()
  ((bar-slot-1 :initform "slot1")
   (bar-slot-2 :initform "slot2")))

(defclass foo ()
  ((bar :initform (make-instance 'bar))))

(defparameter *foo* (make-instance 'foo))
(defparameter *class-test-foo-string* "{\"bar\":{\"bar-slot-1\":\"slot1\",\"bar-slot-2\":\"slot2\"}}")


(deftest :yason "parser.basic"
  (let ((result (yason:parse *basic-test-json-string*)))
    (test-equal (first *basic-test-json-dom*) (first result) :test #'equalp)
    (test-equal (rest *basic-test-json-dom*) (rest result))))

(deftest :yason "parser.basic-with-whitespace"
  (let ((result (yason:parse *basic-test-json-string-indented*)))
    (test-equal (first *basic-test-json-dom*) (first result) :test #'equalp)
    (test-equal (rest *basic-test-json-dom*) (rest result))))

(deftest :yason "dom-encoder.basic"
  (let ((result (yason:parse
                 (with-output-to-string (s)
                   (yason:encode *basic-test-json-dom* s)))))
    (test-equal (first *basic-test-json-dom*) (first result) :test #'equalp)
    (test-equal (rest *basic-test-json-dom*) (rest result))))

(deftest :yason "parser.class"
  (let* ((result (yason:parse *class-test-foo-string* :object-as 'foo))
         (result-bar (slot-value result 'bar))
         (bar (slot-value *foo* 'bar)))
    (describe result-bar)
    (describe bar)
    (test-equal (slot-value result-bar 'bar-slot-1)
                (slot-value bar 'bar-slot-1) :test #'equalp)
    (test-equal (slot-value result-bar 'bar-slot-2)
                (slot-value bar 'bar-slot-2) :test #'equalp)))

(defun whitespace-char-p (char)
  (member char '(#\space #\tab #\return #\newline #\linefeed)))

(deftest :yason "dom-encoder.indentation"
  (test-equal "[
          1,
          2,
          3
]"
              (with-output-to-string (s)
                (yason:encode '(1 2 3) (yason:make-json-output-stream s :indent 10))))
  (dolist (indentation-arg '(nil t 2 20))
    (test-equal "[1,2,3]" (remove-if #'whitespace-char-p
                                     (with-output-to-string (s)
                                       (yason:encode '(1 2 3)
                                                    (yason:make-json-output-stream s :indent indentation-arg)))))))
    
(deftest :yason "stream-encoder.basic-array"
  (test-equal "[0,1,2]"
              (with-output-to-string (s)
                (yason:with-output (s)
                  (yason:with-array ()
                    (dotimes (i 3)
                      (yason:encode-array-element i)))))))

(deftest :yason "stream-encoder.basic-object"
  (test-equal "{\"hello\":\"hu hu\",\"harr\":[0,1,2]}"
              (with-output-to-string (s)
                (yason:with-output (s)
                  (yason:with-object ()
                    (yason:encode-object-element "hello" "hu hu")
                    (yason:with-object-element ("harr")
                      (yason:with-array ()
                        (dotimes (i 3)
                          (yason:encode-array-element i)))))))))

(defstruct user name age password)

(defmethod yason:encode ((user user) &optional (stream *standard-output*))
           (yason:with-output (stream)
             (yason:with-object ()
               (yason:encode-object-element "name" (user-name user))
               (yason:encode-object-element "age" (user-age user)))))

(deftest :yason "stream-encoder.application-struct"
  (test-equal "[{\"name\":\"horst\",\"age\":27},{\"name\":\"uschi\",\"age\":28}]"
              (with-output-to-string (s)
                (yason:encode (list (make-user :name "horst" :age 27 :password "puppy")
                                   (make-user :name "uschi" :age 28 :password "kitten"))
                             s))))

(defmethod yason:encode ((bar bar) &optional (stream *standard-output*))
  (yason:with-output (stream)
    (yason:with-object ()
      (yason:encode-object-element "bar-slot-1" (slot-value bar 'bar-slot-1))
      (yason:encode-object-element "bar-slot-2" (slot-value bar 'bar-slot-2)))))

(defmethod yason:encode ((foo foo) &optional (stream *standard-output*))
  (yason:with-output (stream)
    (yason:with-object ()
      (yason:encode-object-element "bar" (slot-value foo 'bar)))))

(deftest :yason "stream-encoder.application-class"
  (test-equal "{\"bar\":{\"bar-slot-1\":\"slot1\",\"bar-slot-2\":\"slot2\"}}"
              (with-output-to-string (s)
                (yason:encode *foo* s))))
