---
title: Urban Mobility Sensor Dataset
summary: A curated dataset capturing multimodal transit sensor readings across Porto for congestion modeling.
updated: 2024-05-01
license: CC-BY-4.0
download_url: https://example.com/data/urban-mobility.zip
schema:
  - name: timestamp
    description: UTC timestamp of the observation
    type: datetime
  - name: station_id
    description: Unique identifier for the sensor station
    type: string
  - name: bike_count
    description: Number of bikes detected during the interval
    type: integer
  - name: bus_passengers
    description: Estimated passenger count derived from smart card data
    type: integer
---

The dataset aggregates IoT sensors, AVL feeds, and smart card usage to model multimodal congestion patterns. Feature engineering scripts are available in the companion repository.
