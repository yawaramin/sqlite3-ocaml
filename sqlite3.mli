(**************************************************************************)
(*  Copyright (c) 2005 Christian Szegedy <csdontspam@metamatix.com>       *)
(*                                                                        *)
(*  Copyright (c) 2007 Jane Street Holding, LLC                           *)
(*                     Author: Markus Mottl <markus.mottl@gmail.com>      *)
(*                                                                        *)
(*  Permission is hereby granted, free of charge, to any person           *)
(*  obtaining a copy of this software and associated documentation files  *)
(*  (the "Software"), to deal in the Software without restriction,        *)
(*  including without limitation the rights to use, copy, modify, merge,  *)
(*  publish, distribute, sublicense, and/or sell copies of the Software,  *)
(*  and to permit persons to whom the Software is furnished to do so,     *)
(*  subject to the following conditions:                                  *)
(*                                                                        *)
(*  The above copyright notice and this permission notice shall be        *)
(*  included in all copies or substantial portions of the Software.       *)
(*                                                                        *)
(*  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,       *)
(*  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES       *)
(*  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND              *)
(*  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS   *)
(*  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN    *)
(*  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN     *)
(*  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE      *)
(*  SOFTWARE.                                                             *)
(**************************************************************************)

(** API for Sqlite 3.* databases *)

(** {2 Exceptions} *)

exception InternalError of string
(** [InternalError reason] is raised when the bindings detect an
    unknown/unsupported situation. *)

exception Error of string
(** [Error reason] is raised when some SQL operation is called on a
    nonexistent handle and the functions does not return a return code.
    Functions returning return codes communicate errors by returning
    the specific error code. *)

exception RangeError of int * int
(** [RangeError (index, maximum)] is raised if some column or bind
    operation refers to a nonexistent column or binding.  The first
    entry of the returned tuple is the specified index, the second is
    the limit which was violated. *)


(** {2 Types} *)

type db
(** Database handle.  Used to store information regarding open
    databases and the error code from the last operation if the function
    implementing that operation takes a database handle as a parameter.

    NOTE: DO NOT USE THIS HANDLE WITHIN THREADS OTHER THAN THE ONE THAT
    CREATED IT!!!

    NOTE: database handles are closed (see {!db_close}) automatically
    when they are reclaimed by the GC unless they have already been
    closed earlier by the user.  It is good practice to manually close
    database handles to free resources as quickly as possible.
*)

type stmt
(** Compiled statement handle.  Stores information about compiled
    statements created by the [prepare] or [prepare_tail] functions.

    NOTE: DO NOT USE THIS HANDLE WITHIN THREADS OTHER THAN THE ONE THAT
    CREATED IT!!!
*)

type header = string
(** Type of name of a column returned by queries. *)

type headers = header array
(** Type of names of columns returned by queries. *)

type row = string option array
(** Type of row data (with potential NULL-values) *)


(** {2 Return codes} *)

module Rc : sig
  type unknown  (** Type of unknown return codes *)

  external int_of_unknown : unknown -> int = "%identity"
  (** [int_of_unknown n] converts unknown return code [rc] to an
      integer. *)

  (** Type of return codes from failed or successful operations. *)
  type t =
    | OK
    | ERROR
    | INTERNAL
    | PERM
    | ABORT
    | BUSY
    | LOCKED
    | NOMEM
    | READONLY
    | INTERRUPT
    | IOERR
    | CORRUPT
    | NOTFOUND
    | FULL
    | CANTOPEN
    | PROTOCOL
    | EMPTY
    | SCHEMA
    | TOOBIG
    | CONSTRAINT
    | MISMATCH
    | MISUSE
    | NOFLS
    | AUTH
    | FORMAT
    | RANGE
    | NOTADB
    | ROW
    | DONE
    | UNKNOWN of unknown

  val to_string : t -> string
  (** [to_string rc] converts return code [rc] to a string. *)
end


(** {2 Column data types} *)

module Data : sig
  (** Type of columns *)
  type t =
    | NONE
    | NULL
    | INT of int64
    | FLOAT of float
    | TEXT of string
    | BLOB of string

  val to_string : t -> string
  (** [to_string tp] converts column type [tp] to a string. *)
end


(** {2 General database operations} *)

external db_open : string -> db = "caml_sqlite3_open"
(** [db_open filename] opens the database file [filename], and returns
    a database handle. *)

external db_close : db -> bool = "caml_sqlite3_close"
(** [db_close db] closes database [db] and invalidates the handle.
    @return [false] if database was busy (database not closed in this
    case!), [true] otherwise.

    @raise SqliteError if an invalid database handle is passed.
*)

external errcode : db -> Rc.t = "caml_sqlite3_errcode"
(** [errcode db] @return the error code of the last operation on database
    [db].

    @raise SqliteError if an invalid database handle is passed.
*)

external errmsg : db -> string = "caml_sqlite3_errmsg"
(** [errmsg db] @return the error message of the last operation on
    database [db].

    @raise SqliteError if an invalid database handle is passed.
*)

external last_insert_rowid : db -> int64 = "caml_sqlite3_last_insert_rowid"
(** [last_insert_rowid db] @return the index of the row inserted by
    the last operation on database [db].

    @raise SqliteError if an invalid database handle is passed.
*)

external exec :
  db -> string -> (row -> headers -> unit) -> Rc.t = "caml_sqlite3_exec"
(** [exec db sql callback] performs SQL-operation [sql] on database [db].
    If the operation contains query statements, then the callback function
    will be called for each matching row.  The first parameter of the
    callback is the contents of the row, the second paramater are the
    headers of the columns associated with the row.  Exceptions raised
    within the callback will abort the execution and escape {!exec}.

    @return the return code of the operation.

    @raise SqliteError if an invalid database handle is passed.
*)


(** {2 Fine grained query operations} *)

external prepare : db -> string -> stmt = "caml_sqlite3_prepare"
(** [prepare db sql] compile SQL-statement [sql] for database [db]
    into bytecode.  The statement may be only partially compiled.
    In this case {!prepare_tail} can be called on the returned statement
    to compile the remaining part of the SQL-statement.

    @raise SqliteError if an invalid database handle is passed.
    @raise SqliteError if the statement could not be prepared.
*)

external prepare_tail : stmt -> stmt option = "caml_sqlite3_prepare_tail"
(** [prepare_tail stmt] compile the remaining part of the SQL-statement
    [stmt] to bytecode.  @return [None] if there was no remaining part,
    or [Some remaining_part] otherwise.

    @raise SqliteError if the statement could not be prepared.
*)

external recompile : stmt -> unit = "caml_sqlite3_recompile"
(** [recompile stmt] recompiles the SQL-statement associated with [stmt]
    to bytecode.  The statement may be only partially compiled.  In this
    case {!prepare_tail} can be called on the returned statement to
    compile the remaining part of the SQL-statement.  Call this function
    if the statement expires due to some schema change.

    @raise SqliteError if the statement could not be recompiled.
*)

external step : stmt -> Rc.t = "caml_sqlite3_step"
(** [step stmt] performs one step of the query associated with
    SQL-statement [stmt].

    @return the return code of this operation.

    @raise SqliteError if the step could not be executed.
*)

external finalize : stmt -> Rc.t = "caml_sqlite3_stmt_finalize"
(** [finalize stmt] finalizes the statement [stmt].  After finalization,
    the only valid usage of the statement is to use it in {!prepare_tail},
    or to {!recompile} it.

    @return the return code of this operation.

    @raise SqliteError if the statement could not be finalized.
*)

external reset : stmt -> Rc.t = "caml_sqlite3_stmt_reset"
(** [reset stmt] resets the statement [stmt], e.g. to restart the query,
    perhaps with different bindings.

    @return the return code of this operation.

    @raise SqliteError if the statement could not be reset.
*)

external expired : stmt -> bool = "caml_sqlite3_expired"
(** [expired stmt] @return [true] if the statement [stmt] has expired.
    In this case it may need to be recompiled.

    @raise SqliteError if the statement is invalid.
*)


(** {2 Data query} *)

external data_count : stmt -> int = "caml_sqlite3_data_count"
(** [data_count stmt] @return the number of columns in the result of
    the last step of statement [stmt].

    @raise SqliteError if the statement is invalid.
*)

external column : stmt -> int -> Data.t = "caml_sqlite3_column"
(** [column stmt n] @return the data in column [n] of the
    result of the last step of statement [stmt].

    @raise RangeError if [n] is out of range.
    @raise SqliteError if the statement is invalid.
*)

external column_name : stmt -> int -> header = "caml_sqlite3_column_name"
(** [column_name stmt n] @return the header of column [n] of the result
    of the last step of statement [stmt].

    @raise RangeError if [n] is out of range.
    @raise SqliteError if the statement is invalid.
*)

external column_decltype :
  stmt -> int -> string = "caml_sqlite3_column_decltype"
(** [column_decltype stmt n] @return the declared type of the specified
    column of the result of the last step of statement [stmt].

    @raise RangeError if [n] is out of range.
    @raise SqliteError if the statement is invalid.
*)


(** {2 Binding data to the query} *)

external bind : stmt -> int -> Data.t -> Rc.t = "caml_sqlite3_bind"
(** [bind stmt n data] binds the value [data] to the free variable at
    position [n] of statement [stmt].  NOTE: the first variable has
    index [1]!

    @return the return code of this operation.

    @raise RangeError if [n] is out of range.
    @raise SqliteError if the statement is invalid.
*)

external bind_parameter_count :
  stmt -> int = "caml_sqlite3_bind_parameter_count"
(** [bind_parameter_count stmt] @return the number of free variables in
    statement [stmt].

    @raise SqliteError if the statement is invalid.
*)

external bind_parameter_name :
  stmt -> int -> string option = "caml_sqlite3_bind_parameter_name"
(** [bind_parameter_name stmt n] @return [Some parameter_name] of the free
    variable at position [n] of statement [stmt], or [None] if it is
    ordinary ("?").

    @raise RangeError if [n] is out of range.
    @raise SqliteError if the statement is invalid.
*)

external bind_parameter_index :
  stmt -> string -> int = "caml_sqlite3_bind_parameter_index"
(** [bind_parameter_index stmt name] @return the position of the free
    variable with name [name] in statement [stmt].

    @raise Not_found if [name] was not found.
    @raise SqliteError if the statement is invalid.
*)

external transfer_bindings :
  stmt -> stmt -> Rc.t = "caml_sqlite3_transfer_bindings"
(** [transfer_bindings stmt1 stmt2] transfer the bindings of statement
    [stmt1] to [stmt2].

    @return the return code of this operation.

    @raise SqliteError if any of the two statements is invalid.
*)

(* TODO: does not link *)
(* external sleep : int -> unit = "caml_sqlite3_sleep" *)


(** {2 Stepwise query convenience functions} *)

val exec_sql : db -> string -> (stmt -> unit) -> unit
(** [exec_sql db sql f] performs the query [sql] on database [db] in
    a stepwise manner calling [f] with the statement associated with
    [sql] whenever a row is found.

    @raise SqliteError if an invalid database handle is passed.
    @raise SqliteError if the compiled statement should become invalid.
*)

val row_data : stmt -> Data.t array
(** [row_data stmt] @return all data values in the row returned by the
    last query step performed with statement [stmt].

    @raise SqliteError if the statement is invalid.
*)

val row_names : stmt -> headers
(** [row_names stmt] @return all column headers of the row returned by the
    last query step performed with statement [stmt].

    @raise SqliteError if the statement is invalid.
*)

val row_decltypes : stmt -> string array
(** [row_decltypes stmt] @return all column type declarations of the
    row returned by the last query step performed with statement [stmt].

    @raise SqliteError if the statement is invalid.
*)
