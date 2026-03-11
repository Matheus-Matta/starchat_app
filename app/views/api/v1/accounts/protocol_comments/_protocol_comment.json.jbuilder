json.id comment.id
json.content comment.content
json.is_private comment.is_private
json.created_at comment.created_at
json.updated_at comment.updated_at
json.protocol_id comment.protocol_id
json.account_id comment.account_id

# Agente que registrou o comentário
if comment.user
  json.user do
    json.id comment.user.id
    json.name comment.user.name
    json.avatar_url comment.user.avatar_url
  end
else
  json.user nil
end

# Arquivos anexados ao comentário (padrão SAC: fotos, NF, evidências)
json.files comment.files do |file|
  json.id file.id
  json.filename file.filename
  json.content_type file.content_type
  json.byte_size file.byte_size
  json.url url_for(file)
end
