#!/usr/bin/bash
inspec exec test/integration/verify -t azure:// --reporter junit:inspec.out --attrs ../test/integration/build/inspec-attrs.yaml