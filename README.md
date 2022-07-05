The Octopus Energy iOS/web app graphs don't show how much we get paid for the energy the solar panels generate, so we have to work it out for ourselves.

# Install and usage

```shell
docker run \
  -e OCTOPUS_EXPORT_MPAN="<export_meter_mpan>" \
  -e OCTOPUS_ELECTRICITY_METER_SN="<serial_number>" \
  -e OCTOPUS_API_KEY="<api_key>" \
  -e POSTCODE="<postcode>" \
  ghcr.io/issyl0/octopus-export-income:latest-amd64 --from 2022-07-04 --to 2022-07-04
```

Output:

```shell
Total for 2022-07-04: 318.66p, or £3.19.
```

Pass `--verbose` to see the individual half-hourly exports and their earnings.

TODO:

- [x] Installation and usage instructions.
- [ ] Make sure rounding of the displayed numbers is not misleading.
- [x] Configurable dates.
- [ ] Some kind of web interface?
