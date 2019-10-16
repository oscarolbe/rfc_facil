defmodule RfcFacil.NaturalPerson do
  @moduledoc """
  Utilidad para calcular los RFC's de persona físicas
  """

  @vowels ~w(a e i o u)

  @avoidable_words ~w(de el y del los la las)

  @alphabet %{
    " " => "00",
    "0" => "00",
    "1" => "01",
    "2" => "02",
    "3" => "03",
    "4" => "04",
    "5" => "05",
    "6" => "06",
    "7" => "07",
    "8" => "08",
    "9" => "09",
    "&" => "10",
    "A" => "11",
    "B" => "12",
    "C" => "13",
    "D" => "14",
    "E" => "15",
    "F" => "16",
    "G" => "17",
    "H" => "18",
    "I" => "19",
    "J" => "21",
    "K" => "22",
    "L" => "23",
    "M" => "24",
    "N" => "25",
    "O" => "26",
    "P" => "27",
    "Q" => "28",
    "R" => "29",
    "S" => "32",
    "T" => "33",
    "U" => "34",
    "V" => "35",
    "W" => "36",
    "X" => "37",
    "Y" => "38",
    "Z" => "39",
    "Ñ" => "40"
  }

  @homonymy %{
    "0" => 1,
    "1" => 2,
    "2" => 3,
    "3" => 4,
    "4" => 5,
    "5" => 6,
    "6" => 7,
    "7" => 8,
    "8" => 9,
    "9" => "A",
    "10" => "B",
    "11" => "C",
    "12" => "D",
    "13" => "E",
    "14" => "F",
    "15" => "G",
    "16" => "H",
    "17" => "I",
    "18" => "J",
    "19" => "K",
    "20" => "L",
    "21" => "M",
    "22" => "N",
    "23" => "P",
    "24" => "Q",
    "25" => "R",
    "26" => "S",
    "27" => "T",
    "28" => "U",
    "29" => "V",
    "30" => "W",
    "31" => "X",
    "32" => "Y",
    "33" => "Z"
  }

  @verification %{
    "0" => "00",
    "1" => "01",
    "2" => "02",
    "3" => "03",
    "4" => "04",
    "5" => "05",
    "6" => "06",
    "7" => "07",
    "8" => "08",
    "9" => "09",
    "A" => "10",
    "B" => "11",
    "C" => "12",
    "D" => "13",
    "E" => "14",
    "F" => "15",
    "G" => "16",
    "H" => "17",
    "I" => "18",
    "J" => "19",
    "K" => "20",
    "L" => "21",
    "M" => "22",
    "N" => "23",
    "&" => "24",
    "O" => "25",
    "P" => "26",
    "Q" => "27",
    "R" => "28",
    "S" => "29",
    "T" => "30",
    "U" => "31",
    "V" => "32",
    "W" => "33",
    "X" => "34",
    "Y" => "35",
    "Z" => "36",
    " " => "37",
    "Ñ" => "38"
  }

  @doc """
  Calcula el RFC de una persona física, siguiendo con la reglas usadas por
  el Registro Federal de Contribuyentes
  """
  @spec calculate(String.t(), String.t(), String.t(), String.t()) :: String.t()
  def calculate(name, lastname, lastname2, birthdate) do
    name = normalize(name)
    lastname = normalize(lastname)
    lastname2 = normalize(lastname2)

    rfc =
      String.upcase(name_part(name, lastname, lastname2)) <>
        birth_part(birthdate) <> homonymy_part(name, lastname, lastname2)

    digit =
      rfc
      |> String.upcase()
      |> verification_part()

    {:ok, rfc <> digit}
  end

  # Construye la primer parte del RFC en la que solo está involucrado el
  # nombre de la persona
  defp name_part(name, lastname, lastname2) do
    # Si los apellidos tienen artículos o preposiciones, deben eliminarse
    lastname = trim_words(lastname)
    lastname2 = trim_words(lastname2)
    length = String.length(lastname)

    cond do
      # Sin apellido materno
      lastname2 in ["", nil] ->
        String.slice(lastname, 0, 2) <> String.slice(name, 0, 2)

      # Apellido paterno demasiado pequeño
      length <= 2 ->
        String.slice(lastname, 0, 1) <>
          String.slice(lastname2, 0, 1) <>
          String.slice(name, 0, 2)

      # Caso normal
      true ->
        _name_part(name, lastname, lastname2)
    end
  end

  # Caso normal
  # 1. La primera letra del apellido paterno y la siguiente primera vocal del mismo.
  # 2. La primera letra del apellido materno.
  # 3. La primera letra del nombre.
  defp _name_part(name, lastname, lastname2) do
    {first_char, remainder} = String.next_grapheme(lastname)

    first_char <>
      next_vowel(remainder) <>
      String.slice(lastname2, 0, 1) <>
      String.slice(name, 0, 1)
  end

  # Elimina las preposiciones o artículos del apellido
  # Estos no deben ser considerados en el RFC
  defp trim_words(lastname) do
    lastname
    |> String.split(" ")
    |> Enum.reduce("", fn word, acc ->
      word
      |> String.downcase()
      |> (&Enum.member?(@avoidable_words, &1)).()
      |> if do
        acc
      else
        "#{acc} #{word}"
      end
      |> String.trim()
    end)
  end

  # Regresa la fecha de nacimiento en el formato correcto
  defp birth_part(birthdate) do
    birthdate
    |> Timex.parse!("%Y-%m-%d", :strftime)
    |> Timex.format!("%y%m%d", :strftime)
  end

  #  Regresa la clave diferenciadora de homonimia
  defp homonymy_part(name, lastname, lastname2) do
    "#{lastname} #{lastname2} #{name}"
    |> String.upcase()
    |> String.graphemes()
    |> Enum.map_join(fn char -> Map.get(@alphabet, char) end)
    |> String.graphemes()
    |> homonymy_operation()
  end

  # Calcula el resultado de multiplicar la lista de números
  # Se efectuaran las multiplicaciones de los números tomados de
  # dos en dos para la posición de la pareja
  # Se agrega un cero al inicio
  defp homonymy_operation(numbers) do
    result =
      numbers
      |> _homonymy_operation("0")
      |> Kernel.rem(1000)

    first_code =
      result
      |> Kernel.div(34)
      |> Integer.to_string()
      |> (&Map.get(@homonymy, &1)).()

    second_code =
      result
      |> Kernel.rem(34)
      |> Integer.to_string()
      |> (&Map.get(@homonymy, &1)).()

    "#{first_code}#{second_code}"
  end

  # Va multiplicando la pareja de números y sumando los resultados
  defp _homonymy_operation([], _), do: 0

  defp _homonymy_operation([next | remain], past_number) do
    next_number = String.to_integer(next)

    "#{past_number}#{next_number}"
    |> String.strip()
    |> String.to_integer()
    |> Kernel.*(next_number)
    |> Kernel.+(_homonymy_operation(remain, next_number))
  end

  # Regresa el número verificador
  defp verification_part(rfc) do
    number =
      rfc
      |> String.graphemes()
      |> Enum.map(fn char -> Map.get(@verification, char) end)
      |> Enum.with_index()
      |> Enum.reduce(0, fn {number, index}, acc ->
        String.to_integer(number) * (13 - index) + acc
      end)
      |> Kernel.rem(11)

    cond do
      number == 0 -> "0"
      number in [1, 10] -> "A"
      true -> to_string(11 - number)
    end
  end

  # Regresa la siguiente vocal
  defp next_vowel(string) do
    with {char, remainder} <- String.next_grapheme(string) do
      if Enum.member?(@vowels, char), do: char, else: next_vowel(remainder)
    else
      nil -> nil
    end
  end

  # Quita las tildes
  defp normalize(string) do
    string
    |> String.normalize(:nfd)
    |> String.codepoints()
    |> Enum.reject(&Regex.match?(~r/[^"̃A-Za-z&\s]/u, &1))
    |> Enum.join()
    |> String.downcase()
  end
end