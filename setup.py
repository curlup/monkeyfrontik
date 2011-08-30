from setuptools import setup

setup(
    name = "monkeyfrontik",
    description = "monkey pathced Frontik with some profiling added",
    url = "https://github.com/hhru/frontik",
    scripts = ["scripts/monkeyfrontik"],
    install_requires = [
        "frontik >= 2.9.0",
    ],
    zip_safe = False
)
