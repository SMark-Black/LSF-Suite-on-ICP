# LSF-Suite-on-ICP

This repository contains the files needed to package IBM Spectrum LSF Suite 10.2 Enterprise, HPC or Workgroup edition to work in IBM Cloud Private.  IBM Spectrum LSF is a workload manager that provides support for traditional high-performance computing (hpc) and high throughput (htc) workloads, as well as for big data, cognitive, GPU machine learning, and containerized workloads. LSF itself can run on bare metal, within a VM or within a container. This repository contains the files needed to help achieve the latter.

Many people view containerisation as a more lightweight form of virtualisation.    When you create a VM it needs to have configuration information on corporate DNS, LDAP, file systems to mount etc - if the VM just contains LSF on its own, (ie no applications either on local virtual disk or mounted) then there is nothing for LSF to schedule.  The VM is only really good for examining LSF functionality, but not really useful for production workload.   

The same is true with containerisation - a container that contains just LSF can't run any applications itself.     ICP provides a containerised version of LSF Community Edition, which is great for evaluating LSF capabilities, but the container lacks the integration with necessary external services (e.g. ldap, nfs) and applications to run.      

A blog discussing how to build a production ready container for use with ICP that contains LSF and the applications you want to run is available here:  https://wp.me/p7QJOG-1Cz

