# aix_lvm_facts

#### Table of Contents

1. [Description](#description)
1. [Setup - The basics of getting started with aix_lvm_facts](#setup)
    * [What aix_lvm_facts affects](#what-aix_lvm_facts-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with aix_lvm_facts](#beginning-with-aix_lvm_facts)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
1. [Limitations - OS compatibility, etc.](#limitations)
1. [Development - Guide for contributing to the module](#development)

## Description

The cryssoft-aix_lvm_facts module populates the $::facts['aix_lvs'] and $::facts['aix_vgs'] 
hashes with values that are of interest if you're using Puppet to manage AIX systems and want
more than the built-in data types/resources to use in your code.  They may be useful in
concert with the puppetlabs-lvm module which doesn't seem to provide such facts for AIX nodes.

The values in $::facts['aix_vgs']['lvs'] and $::facts['aix_vgs']['pvs'] have different 
formats, with and without the leading /dev/, so that they can be used as keys into the
built-in $::facts['partitions'] and $::facts['disks'] if needed.

NOTE:  The values in $::facts['aix_vgs']['vgtype'] come from the semi-documented "readvgda" 
command.  The documentation says the values can change depending on your AIX version, etc.
I have yet to find any exhaustive list of what values really mean what.

For the bulk of my systems, "smallvg" is a normal VG and "svg" is a scalable VG.  I have no
"big" VGs to test with at the moment.  There are other values in other boxes that don't 
necessarily match up to any expactations like "mpvg", "vg_type: 2", etc.

## Setup

Put the module in place in your Puppet master server as usual.  AIX-based systems
will start populating the $::facts['aix_lvs'] and $::facts['aix_vgs'] hashes with their
next run, and you can start referencing those facts in your classes.

### What aix_lvm_facts affects

At this time, the cryssoft-aix_lvm_facts module ONLY supplies custom facts.  It 
does not change anything and should have no side-effects.

### Setup Requirements

As a custom facts module, I believe pluginsync must be enabled for this to work.

These hashes can be pretty large, so they may add up in terms of space in the Puppet 
master or PuppetDB server in your environment.

### Beginning with aix_lvm_facts

If you're using Puppet Enterprise, the new fact(s) will show up in the PE console
for each AIX-based node under management.  If you're not using Puppet Enterprise,
you'll need to use a different approach to checking for their existence and values.

## Usage

As notes, cryssoft-aix_lvm_facts is only providing custom facts.  Once the module
and its Ruby payload are distributed to your AIX-based nodes, those facts will be
available in your classes.

## Reference

$::facts['aix_lvs'] and $::facts['aix_vgs'] are the tops of (potentially) large hashes
of configuration and run-time data.

## Limitations

This should work on any AIX-based system.  

NOTE:  This module has been tested on AIX 6.1, 7.1, and 7.2.

## Development

Make suggestions.  Look at the code on github.  Send updates or outputs.  I don't have
a specific set of rules for contributors at this point.

## Release Notes/Contributors/Etc.

Starting with 0.3.0 - Pretty simple stuff.  Not sure if this will ever morph into a
control/configuration module with types/providers/etc. to actually do anything 
meaningful about controlling AIX LVM configurations.
