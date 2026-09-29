# TUI Visualizer for Mosquito

This is an minimal implementation of a queue visualizer for [mosquito](https://github.com/mosquito-cr/mosquito). It is a [Text based User Interface (TUI)](https://github.com/robacarp/keimeno).

<img width="832" alt="image" src="https://user-images.githubusercontent.com/208647/163231172-7a8c278a-d7f2-4983-badb-56d4a11a72e7.png">

## Purpose

This repository is primarily an experiment on basic queue visualization. It
primarily serves as a testing ground for methods which need to be added to
mosquito core to facilitate this kind of work. In the mean time, it can also be
used to get some idea that things are happening in a deployed worker, and the
rate at which they are happening.

## Using the visualizer

Using the visualizer to query a running mosquito backend is straightforward.
This will increase the read-load on the backend slightly.

- Clone the visualizer and install shards:

```console
$ git clone git@github.com:mosquito-cr/tui_visualizer.git
$ cd tui_visualizer
$ shards install
```

- Provide REDIS_URL connection string as `REDIS_ENV` environment variable. If
  needed, the connection can be piped over [SSH with a
  tunnel](https://duckduckgo.com/?q=ssh+tunnel&ia=web). In a production
  environment, you'll need to provide your auth key here in this url (and
  perhaps an acl user as well).

```console
$ export REDIS_URL 'redis://localhost:6379/2'
```

- Boot the interface
```console
$ crystal run ./interface.cr
```

## Developing the visualizer

A utility script is provided to enqueue and execute some jobs, which is
convenient for working on the visualizer. Use `crystal run interactive_runner.cr`
to run it.


The web interface can reload the browser when files change. This needs
[libfswatch](https://github.com/emcrisostomo/fswatch) and is only compiled in
with the `hot_reload` flag, which `scripts/web_dev` passes:

```console
$ crystal run -Dhot_reload web_interface.cr
```
